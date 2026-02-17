%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <math.h>

void yyerror(const char *s);
int yylex();

/* ===== Storage ===== */

#define MAX_NOTES 500

int tempo = 120;
int tempo_set = 0;  
char notes[MAX_NOTES][10];
int durations[MAX_NOTES];
int note_count = 0;

/* Repeat stack for nested repeats */
int repeat_stack[20];        // stores repeat counts
int repeat_start_stack[20];  // stores start indices
int repeat_top = -1;         // stack pointer

/* ===== Convert note to frequency ===== */

int note_to_freq(const char* note) {
    // Handle REST
    if(strcmp(note, "REST") == 0) return 0;
    
    char base = note[0];
    int octave = note[strlen(note)-1] - '0';
    int semitone = 0;

    switch(base) {
        case 'C': semitone = 0; break;
        case 'D': semitone = 2; break;
        case 'E': semitone = 4; break;
        case 'F': semitone = 5; break;
        case 'G': semitone = 7; break;
        case 'A': semitone = 9; break;
        case 'B': semitone = 11; break;
    }

    if(note[1] == '#') semitone += 1;
    if(note[1] == 'b') semitone -= 1;

    int n = (octave + 1) * 12 + semitone;
    double freq = 440.0 * pow(2, (n - 69) / 12.0);

    return (int)freq;
}

/* ===== Convert note to MIDI note number ===== */

int note_to_midi(const char* note) {
    if(strcmp(note, "REST") == 0) return 0;
    
    char base = note[0];
    int octave = note[strlen(note)-1] - '0';
    int semitone = 0;

    switch(base) {
        case 'C': semitone = 0; break;
        case 'D': semitone = 2; break;
        case 'E': semitone = 4; break;
        case 'F': semitone = 5; break;
        case 'G': semitone = 7; break;
        case 'A': semitone = 9; break;
        case 'B': semitone = 11; break;
    }

    if(note[1] == '#') semitone += 1;
    if(note[1] == 'b') semitone -= 1;

    // MIDI note number: C4 = 60, C5 = 72, etc.
    return (octave + 1) * 12 + semitone;
}

/* ===== Play Music (PC Speaker) ===== */

void play_music() {
    printf("\nPlaying Music via PC Speaker...\n");

    for(int i = 0; i < note_count; i++) {
        int duration_ms = (60000 / tempo) * durations[i];

        if(strcmp(notes[i], "REST") == 0) {
            Sleep(duration_ms);
        } else {
            int freq = note_to_freq(notes[i]);
            Beep(freq, duration_ms);
        }
    }
    
    printf("PC Speaker playback finished!\n");
}

/* ===== MIDI Generation Functions ===== */

void write_int_big_endian(FILE *file, int value, int bytes) {
    for(int i = bytes - 1; i >= 0; i--) {
        fputc((value >> (i * 8)) & 0xFF, file);
    }
}

void write_variable_length(FILE *file, int value) {
    unsigned int buffer = value & 0x7F;
    
    while((value >>= 7)) {
        buffer <<= 8;
        buffer |= ((value & 0x7F) | 0x80);
    }

    while(1) {
        fputc(buffer & 0xFF, file);
        if(buffer & 0x80)
            buffer >>= 8;
        else
            break;
    }
}

void generate_midi(const char* filename) {
    FILE *file = fopen(filename, "wb");
    if(!file) {
        printf("Error creating MIDI file!\n");
        return;
    }

    printf("\nGenerating MIDI file: %s\n", filename);

    /* MIDI Header */
    fwrite("MThd", 1, 4, file);
    write_int_big_endian(file, 6, 4);     // header length
    write_int_big_endian(file, 0, 2);     // format 0
    write_int_big_endian(file, 1, 2);     // 1 track
    write_int_big_endian(file, 480, 2);   // ticks per quarter note

    /* Track Chunk */
    fwrite("MTrk", 1, 4, file);

    long track_size_position = ftell(file);
    write_int_big_endian(file, 0, 4);     // placeholder for track size

    long track_start = ftell(file);

    /* Set Tempo */
    int microseconds_per_quarter = 60000000 / tempo;

    write_variable_length(file, 0);       // delta time = 0
    fputc(0xFF, file);                    // meta event
    fputc(0x51, file);                    // set tempo
    fputc(0x03, file);                    // length = 3 bytes
    write_int_big_endian(file, microseconds_per_quarter, 3);

    /* Write Notes */
    int current_time = 0;
    
    for(int i = 0; i < note_count; i++) {
        int duration_ticks = 480 * durations[i];

        if(strcmp(notes[i], "REST") != 0) {
            int midi_note = note_to_midi(notes[i]);
            
            // Note On event
            write_variable_length(file, 0);        // delta time from previous event
            fputc(0x90, file);                      // note on, channel 0
            fputc(midi_note, file);                  // pitch
            fputc(100, file);                        // velocity

            // Note Off event (after duration)
            write_variable_length(file, duration_ticks);
            fputc(0x80, file);                      // note off, channel 0
            fputc(midi_note, file);                  // pitch
            fputc(0, file);                          // velocity (0 for note off)

        } else {
            // Rest - just advance time
            current_time += duration_ticks;
        }
    }

    /* End of Track */
    write_variable_length(file, 0);        // delta time = 0
    fputc(0xFF, file);                      // meta event
    fputc(0x2F, file);                      // end of track
    fputc(0x00, file);                      // length = 0

    /* Write track size */
    long track_end = ftell(file);
    int track_size = track_end - track_start;

    fseek(file, track_size_position, SEEK_SET);
    write_int_big_endian(file, track_size, 4);

    fclose(file);
    printf("MIDI file generated successfully: %s\n", filename);
}

/* ===== Debug function to see what's stored ===== */

void print_music() {
    printf("\n=== Music Summary ===\n");
    printf("Tempo: %d BPM\n", tempo);
    printf("Total notes/rests: %d\n", note_count);
    
    for(int i = 0; i < note_count; i++) {
        printf("%3d: %s (duration %d)", i+1, notes[i], durations[i]);
        
        // Show MIDI note number for notes (not rests)
        if(strcmp(notes[i], "REST") != 0) {
            printf(" → MIDI note: %d", note_to_midi(notes[i]));
        }
        printf("\n");
    }
    printf("===================\n");
}

%}

/* ===== UNION ===== */

%union {
    int number;
    char* string;
}

/* ===== TOKENS ===== */

%token TOKEN_SONG
%token TOKEN_PLAY
%token TOKEN_TEMPO
%token TOKEN_REPEAT
%token TOKEN_REST
%token TOKEN_STOP
%token TOKEN_FOR
%token TOKEN_LBRACE
%token TOKEN_RBRACE
%token TOKEN_SEMICOLON

%token <string> TOKEN_NOTE
%token <string> TOKEN_IDENTIFIER
%token <number> TOKEN_NUMBER

%%

program:
    TOKEN_SONG TOKEN_IDENTIFIER TOKEN_LBRACE statements TOKEN_RBRACE
    {
        printf("\nValid Music Program\n");

        if(!tempo_set) {
            printf("No tempo specified. Using default tempo 120 BPM.\n");
        }

        
        print_music();                   
        generate_midi("output.mid");      
        play_music();                      
    }
;

statements:
    statements statement
    |
;

statement:
      tempo_statement
    | play_statement
    | rest_statement
    | repeat_statement
    | stop_statement
;

tempo_statement:
    TOKEN_TEMPO TOKEN_NUMBER TOKEN_SEMICOLON
    {
        if($2 < 30 || $2 > 300) {
            printf("Error: Tempo must be between 30 and 300 BPM.\n");
            exit(1);
        }

        tempo = $2;
        tempo_set = 1;
        printf("Tempo set to %d BPM\n", tempo);
    }
;

play_statement:
    TOKEN_PLAY TOKEN_NOTE TOKEN_FOR TOKEN_NUMBER TOKEN_SEMICOLON
    {
        if(note_count < MAX_NOTES) {
            strcpy(notes[note_count], $2);
            durations[note_count] = $4;
            note_count++;
            printf("Added note: %s (duration %d)\n", $2, $4);
        } else {
            printf("Maximum notes reached! Cannot add %s\n", $2);
        }
    }
;

rest_statement:
    TOKEN_REST TOKEN_NUMBER TOKEN_SEMICOLON
    {
        if(note_count < MAX_NOTES) {
            strcpy(notes[note_count], "REST");
            durations[note_count] = $2;
            note_count++;
            printf("Added rest (duration %d)\n", $2);
        }
    }
;

/* ===== Repeat Support ===== */

repeat_statement:
    TOKEN_REPEAT TOKEN_NUMBER TOKEN_LBRACE
    {
        // Push repeat info onto stack when we see "repeat N {"
        repeat_top++;
        repeat_stack[repeat_top] = $2;
        repeat_start_stack[repeat_top] = note_count;
        printf("Starting repeat block (%d times) at note %d\n", 
               $2, note_count + 1);
    }
    statements
    TOKEN_RBRACE
    {
        // When we see "}", duplicate the block N-1 more times
        int times = repeat_stack[repeat_top];
        int start = repeat_start_stack[repeat_top];
        int end = note_count;
        int block_size = end - start;
        
        printf("Repeating block from note %d to %d, %d times\n", 
               start + 1, end, times);

        // Duplicate the block (times-1) more times
        for(int t = 1; t < times; t++) {
            for(int i = 0; i < block_size; i++) {
                if(note_count < MAX_NOTES) {
                    strcpy(notes[note_count], notes[start + i]);
                    durations[note_count] = durations[start + i];
                    note_count++;
                }
            }
        }
        
        printf("Repeat block completed. Now at note %d\n", note_count);
        repeat_top--;
    }
;

stop_statement:
    TOKEN_STOP TOKEN_SEMICOLON
    {
        printf("Stop encountered.\n");
    }
;

%%

void yyerror(const char *s) {
    printf("Syntax Error: %s\n", s);
}

int main() {
    printf("Music Compiler Started...\n");
    printf("============================\n");
    return yyparse();
}