%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "music.tab.h"

int line_number = 1;
%}

ID          [a-zA-Z][a-zA-Z0-9]*
NOTE        [A-G][#b]?[0-8]
NUMBER      [0-9]+

%%

"song"      { return TOKEN_SONG; }
"play"      { return TOKEN_PLAY; }
"tempo"     { return TOKEN_TEMPO; }
"repeat"    { return TOKEN_REPEAT; }
"rest"      { return TOKEN_REST; }
"stop"      { return TOKEN_STOP; }
"for"       { return TOKEN_FOR; }

{NOTE}      {
                yylval.string = strdup(yytext);
                return TOKEN_NOTE;
            }

{ID}        {
                yylval.string = strdup(yytext);
                return TOKEN_IDENTIFIER;
            }

{NUMBER}    {
                yylval.number = atoi(yytext);
                return TOKEN_NUMBER;
            }

"{"         { return TOKEN_LBRACE; }
"}"         { return TOKEN_RBRACE; }
";"         { return TOKEN_SEMICOLON; }

[ \t]+      ;
\n          { line_number++; }

.           { printf("LEXICAL ERROR: %s at line %d\n", yytext, line_number); }

%%

int yywrap() { return 1; }
