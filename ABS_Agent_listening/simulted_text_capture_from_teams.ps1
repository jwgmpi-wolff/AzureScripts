# ===========================
# Teams Bot: Join Scheduled Meeting + Audio Capture + Azure Speech
# ===========================

# Load required assemblies (adjust paths as needed)
$assemblies = @(
    "System.Net.Http",
    "Microsoft.Graph.Communications.Calls.dll",
    "Microsoft.Graph.Communications.Client.dll",
    "Microsoft.CognitiveServices.Speech.csharp.dll"
)

Add-Type -Language CSharp -ReferencedAssemblies $assemblies -TypeDefinition @"
using System;
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

public class TeamsBot
{
    private string appId;
    private string appSecret;
    private string tenantId;
    private string speechKey;
    private string speechRegion;
    private string joinUrl;

    public TeamsBot(string appId, string appSecret, string tenantId, string speechKey, string speechRegion, string joinUrl)
    {
        this.appId = appId;
        this.appSecret = appSecret;
        this.tenantId = tenantId;
        this.speechKey = speechKey;
        this.speechRegion = speechRegion;
        this.joinUrl = joinUrl;
    }

    public async Task StartAsync()
    {
        Console.WriteLine("Joining scheduled Teams meeting...");

        // 1. Authenticate with Microsoft Identity
        var confidentialClient = ConfidentialClientApplicationBuilder.Create(appId)
            .WithClientSecret(appSecret)
            .WithAuthority($"https://login.microsoftonline.com/{tenantId}")
            .Build();

        var token = await confidentialClient.AcquireTokenForClient(new[] { "https://graph.microsoft.com/.default" }).ExecuteAsync();

        var authProvider = new DelegateAuthenticationProvider(async (requestMessage) =>
        {
            requestMessage.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token.AccessToken);
        });

        var graphClient = new GraphServiceClient(authProvider);

        // 2. Create Call object using JoinWebUrl
        var call = new Call
        {
            CallbackUri = "https://<yourdomain>/api/calls",
            MediaConfig = new ServiceHostedMediaConfig(),
            RequestedModalities = new[] { Modality.Audio },
            MeetingInfo = new JoinMeetingIdMeetingInfo
            {
                JoinWebUrl = joinUrl
            }
        };

        var createdCall = await graphClient.Communications.Calls.Request().AddAsync(call);
        Console.WriteLine($"Bot joined meeting: {createdCall.Id}");

        // NOTE: Actual media handling requires Graph Calling SDK media pipeline
        // Here we simulate audio capture and send to Azure Speech
        await StartTranscriptionAsync();
    }

    private async Task StartTranscriptionAsync()
    {
        Console.WriteLine("Starting transcription...");

        var speechConfig = SpeechConfig.FromSubscription(speechKey, speechRegion);
        speechConfig.SpeechRecognitionLanguage = "en-US";

        using var audioStream = AudioInputStream.CreatePushStream();
        using var audioConfig = AudioConfig.FromStreamInput(audioStream);
        using var recognizer = new SpeechRecognizer(speechConfig, audioConfig);

        // Simulate continuous recognition (replace with real audio from Teams)
        recognizer.Recognizing += (s, e) => Console.WriteLine($"Partial: {e.Result.Text}");
        recognizer.Recognized += (s, e) => Console.WriteLine($"Final: {e.Result.Text}");

        await recognizer.StartContinuousRecognitionAsync();
        Console.WriteLine("Listening... Press Ctrl+C to stop.");
        await Task.Delay(-1);
    }
}

public class ConsoleLogger : IGraphLogger
{
    public void Info(string message) => Console.WriteLine($"INFO: {message}");
    public void Warn(string message) => Console.WriteLine($"WARN: {message}");
    public void Error(string message) => Console.WriteLine($"ERROR: {message}");
    public void Verbose(string message) => Console.WriteLine($"VERBOSE: {message}");
    public void Log(LogLevel level, string message) => Console.WriteLine($"{level}: {message}");
}
"@

# ===========================
# PowerShell Execution
# ===========================
$appId = "<YOUR_APP_ID>"
$appSecret = "<YOUR_APP_SECRET>"
$tenantId = "<YOUR_TENANT_ID>"
$speechKey = "<YOUR_SPEECH_KEY>"
$speechRegion = "<YOUR_SPEECH_REGION>"
$joinUrl = "<MEETING_JOIN_URL>"  # From Teams invite

$bot = New-Object TeamsBot($appId, $appSecret, $tenantId, $speechKey, $speechRegion, $joinUrl)
$bot.StartAsync().GetAwaiter().GetResult()



