using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;

namespace MusicCompilerUI
{
    public partial class MainWindow : Window
    {
        private readonly string _workingDirectory;
        private readonly string _compilerExe;
        private readonly string _midiFile;

        public MainWindow()
        {
            InitializeComponent();

            _workingDirectory = AppDomain.CurrentDomain.BaseDirectory;
            _compilerExe = Path.Combine(_workingDirectory, "music.exe");
            _midiFile = Path.Combine(_workingDirectory, "output.mid");

            LoadSample();
            UpdateStatus("Ready", "#55FF55");
        }

        // ===============================
        // UI Helpers
        // ===============================

        private void UpdateStatus(string message, string colorHex)
        {
            CompileStatus.Text = message;
            CompileStatus.Foreground =
                new SolidColorBrush((Color)ColorConverter.ConvertFromString(colorHex));
        }

        private void AppendOutput(string text)
        {
            OutputConsole.Text += text + Environment.NewLine;
            OutputConsole.ScrollToEnd();
        }

        private void ClearOutput()
        {
            OutputConsole.Clear();
        }

        // ===============================
        // Sample Loader
        // ===============================

        private void LoadSample()
        {
            CodeEditor.Text = @"song MyFirstSong {
    tempo 120;
    play C4 for 1;
    play D4 for 1;
    play E4 for 2;
    rest 1;
    repeat 2 {
        play F4 for 1;
        play G4 for 1;
    }
    play A4 for 2;
    stop;
}";
        }

        private void LoadSample_Click(object sender, RoutedEventArgs e)
        {
            LoadSample();
            UpdateStatus("Sample loaded", "#55FF55");
        }

        private void ClearButton_Click(object sender, RoutedEventArgs e)
        {
            CodeEditor.Clear();
            ClearOutput();
            UpdateStatus("Cleared", "#999999");
        }

        // ===============================
        // Compile Logic (Async)
        // ===============================

        private async void CompileButton_Click(object sender, RoutedEventArgs e)
        {
            ClearOutput();

            if (!File.Exists(_compilerExe))
            {
                UpdateStatus("music.exe not found", "#FF5555");
                AppendOutput("ERROR: music.exe not found in application directory.");
                return;
            }

            UpdateStatus("Compiling...", "#FFA500");

            string sourceCode = CodeEditor.Text;

            var result = await RunCompilerAsync(sourceCode);

            AppendOutput(result.Output);

            if (result.ExitCode == 0)
            {
                UpdateStatus("Compilation successful", "#55FF55");

                if (File.Exists(_midiFile))
                {
                    AppendOutput("MIDI file generated: output.mid");
                }
                else
                {
                    AppendOutput("Warning: No MIDI file generated.");
                }
            }
            else
            {
                UpdateStatus("Compilation failed", "#FF5555");
            }
        }

        private Task<CompilerResult> RunCompilerAsync(string source)
        {
            return Task.Run(() =>
            {
                var psi = new ProcessStartInfo
                {
                    FileName = _compilerExe,
                    WorkingDirectory = _workingDirectory,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                var outputBuilder = new StringBuilder();

                using (var process = new Process())
                {
                    process.StartInfo = psi;
                    process.Start();

                    process.StandardInput.Write(source);
                    process.StandardInput.Close();

                    outputBuilder.AppendLine(process.StandardOutput.ReadToEnd());
                    outputBuilder.AppendLine(process.StandardError.ReadToEnd());

                    process.WaitForExit();

                    return new CompilerResult
                    {
                        Output = outputBuilder.ToString(),
                        ExitCode = process.ExitCode
                    };
                }
            });
        }

        // ===============================
        // MIDI Playback
        // ===============================

        private void PlayButton_Click(object sender, RoutedEventArgs e)
        {
            if (!File.Exists(_midiFile))
            {
                UpdateStatus("No MIDI file", "#FF5555");
                AppendOutput("Please compile first.");
                return;
            }

            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = _midiFile,
                    UseShellExecute = true
                });

                UpdateStatus("Playing MIDI", "#007ACC");
            }
            catch (Exception ex)
            {
                UpdateStatus("Playback error", "#FF5555");
                AppendOutput("Playback error: " + ex.Message);
            }
        }

        // ===============================
        // Line Numbers
        // ===============================

        private void CodeEditor_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
        {
            int lineCount = CodeEditor.LineCount;
            StringBuilder sb = new StringBuilder();

            for (int i = 1; i <= lineCount; i++)
                sb.AppendLine(i.ToString());

            LineNumbers.Text = sb.ToString();
        }

        // ===============================
        // Helper Class
        // ===============================

        private class CompilerResult
        {
            public string Output { get; set; }
            public int ExitCode { get; set; }
        }
    }
}
