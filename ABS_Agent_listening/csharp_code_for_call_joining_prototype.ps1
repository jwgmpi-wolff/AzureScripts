 using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Graph;
using Microsoft.Graph.Communications.Calls;
using Microsoft.Graph.Communications.Client;
using Microsoft.Graph.Communications.Common.Telemetry;
using Microsoft.Graph.Communications.Calls.Media;
using Microsoft.Graph.Communications.Calls.Models;
using Microsoft.Graph.Communications.Resources;
using Microsoft.Identity.Client;
using Microsoft.CognitiveServices.Speech;
using Microsoft.CognitiveServices.Speech.Audio;

namespace TeamsCallingBot
{
    class Program
    {
        private static string appId = "<YOUR_APP_ID>";
        private static string appSecret = "<YOUR_APP_SECRET>";
        private static string tenantId = "<YOUR_TENANT_ID>";
        private static string botBaseUrl = "https://<yourdomain>/api/calls"; // Bot endpoint
        private static string speechKey = "<YOUR_SPEECH_KEY>";
        private static string speechRegion = "<YOUR_SPEECH_REGION>";

        static async Task Main(string[] args)
        {
            Console.WriteLine("Starting Teams Calling Bot with Audio Capture...");

            // 1. Authenticate with Microsoft Identity
            var confidentialClient = ConfidentialClientApplicationBuilder.Create(appId)
                .WithClientSecret(appSecret)
                .WithAuthority($"https://login.microsoftonline.com/{tenantId}")
                .Build();

            var authProvider = new DelegateAuthenticationProvider(async (requestMessage) =>
            {
                var token = await confidentialClient.AcquireTokenForClient(new[] { "https://graph.microsoft.com/.default" }).ExecuteAsync();
                requestMessage.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token.AccessToken);
            });

            // 2. Create Graph Communications Client
            var logger = new ConsoleLogger();
            var commsClient = new CommunicationsClient(appId, logger);

            // 3. Subscribe to incoming calls
            commsClient.Calls().OnIncoming += async (sender, callArgs) =>
            {
                Console.WriteLine("Incoming call detected...");
                var call = callArgs.Call;

                // Accept the call with audio media
                await call.AcceptAsync(new ServiceHostedMediaConfig(), new[] { MediaType.Audio });
                Console.WriteLine("Call accepted and joined.");

                // Attach audio socket for media streaming
                call.GetLocalMediaSession().AudioSocket.AudioMediaReceived += async (audioSender, audioArgs) =>
                {
                    Console.WriteLine("Audio packet received...");
                    await ProcessAudioAsync(audioArgs.Buffer);
                };
            };

            Console.WriteLine("Bot is running. Press any key to exit...");
            Console.ReadKey();
        }

        private static async Task ProcessAudioAsync(byte[] audioBuffer)
        {
            // Convert PCM audio to stream for Azure Speech
            using var audioStream = AudioInputStream.CreatePushStream();
            audioStream.Write(audioBuffer);

            var speechConfig = SpeechConfig.FromSubscription(speechKey, speechRegion);
            speechConfig.SpeechRecognitionLanguage = "en-US";

            using var audioConfig = AudioConfig.FromStreamInput(audioStream);
            using var recognizer = new SpeechRecognizer(speechConfig, audioConfig);

            var result = await recognizer.RecognizeOnceAsync();
            Console.WriteLine($"Transcription: {result.Text}");
        }
    }

    // Simple console logger for debugging
    public class ConsoleLogger : IGraphLogger
    {
        public void Info(string message) => Console.WriteLine($"INFO: {message}");
        public void Warn(string message) => Console.WriteLine($"WARN: {message}");
        public void Error(string message) => Console.WriteLine($"ERROR: {message}");
        public void Verbose(string message) => Console.WriteLine($"VERBOSE: {message}");
        public void Log(LogLevel level, string message) => Console.WriteLine($"{level}: {message}");
    }
}













