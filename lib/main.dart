import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'ota/bloc/ota_bloc.dart';
import 'ota/bloc/ota_event.dart';
import 'ota/bloc/ota_state.dart';
import 'ota/repository/ota_repository.dart';
import 'ota/service/native_bridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using platform-specific credentials
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) => OtaRepository(),
      child: BlocProvider(
        create: (context) => OtaBloc(
          repository: context.read<OtaRepository>(),
        )..add(CheckForUpdatesEvent()), // Automatic check triggered on launch
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: HomeScreen(),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _detectedAbi = "Detecting...";

  @override
  void initState() {
    super.initState();
    _resolveDeviceAbi();
  }

  Future<void> _resolveDeviceAbi() async {
    final abi = await NativeBridge.getDeviceAbi();
    if (mounted) {
      setState(() {
        _detectedAbi = abi;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          "Flutter Android OTA Engine",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Recheck for Updates",
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<OtaBloc>().add(CheckForUpdatesEvent());
            },
          ),
        ],
      ),
      body: BlocListener<OtaBloc, OtaState>(
        listener: (context, state) async {
          final messenger = ScaffoldMessenger.of(context);

          // ===================================================================
          // CONSTRAINT 2: Complete Native Memory Hard-Kill Process
          // Once BLoC status emits 'OtaUpdateStagedSuccess', instantly purge
          // dynamic memory segments via native crash-restart.
          // ===================================================================
          if (state is OtaUpdateStagedSuccess) {
            messenger.showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "OTA Staged for ${state.abi}! Purging memory and restarting in 1s...",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 3),
              ),
            );

            // Brief delay allowing filesystem sync and UI snackbar render
            await Future.delayed(const Duration(milliseconds: 1200));

            // Invoke Native Hard-Kill
            await NativeBridge.restartAndHardKillProcess();
          }

          if (state is OtaRollbackErrorState) {
            messenger.showSnackBar(
              SnackBar(
                content: Text("🚨 Rollback Guard: ${state.message}"),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Engine Status Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "AOT Dynamic Engine V1.0",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildInfoRow(
                        "Runtime ABI Resolver:",
                        _detectedAbi,
                        Icons.memory,
                        Colors.cyanAccent,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        "Integrity Algorithm:",
                        "SHA-256 Chunked Stream",
                        Icons.security,
                        Colors.amberAccent,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        "Memory Lifecycle:",
                        "Atomic Swap + Hard SIGKILL",
                        Icons.power_settings_new,
                        Colors.purpleAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Live OTA State Monitor Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Center(
                      child: BlocBuilder<OtaBloc, OtaState>(
                        builder: (context, state) {
                          if (state is OtaCheckingState) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                CircularProgressIndicator(color: Colors.cyanAccent),
                                SizedBox(height: 18),
                                Text(
                                  "Resolving architecture & checking Remote Config...",
                                  style: TextStyle(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }

                          if (state is OtaDownloadingState) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LinearProgressIndicator(
                                  value: state.progress > 0 ? state.progress / 100 : null,
                                  backgroundColor: const Color(0xFF334155),
                                  color: Colors.cyanAccent,
                                  minHeight: 8,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Streaming & hashing ${state.abi.toUpperCase()} binary...",
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  state.progress > 0
                                      ? "${state.progress.toStringAsFixed(1)}%"
                                      : "Connecting stream...",
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }

                          if (state is OtaUpdateStagedSuccess) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 54),
                                const SizedBox(height: 12),
                                Text(
                                  "Staged Version ${state.version} (${state.abi})",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "Cryptographic SHA-256 match validated.\nNative process hard-kill triggered.",
                                  style: TextStyle(color: Colors.white60),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }

                          if (state is OtaRollbackErrorState) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 48),
                                const SizedBox(height: 12),
                                const Text(
                                  "Safe Engine Rollback",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  state.message,
                                  style: const TextStyle(color: Colors.white60),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }

                          if (state is OtaNoUpdateAvailable) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, color: Colors.blueAccent, size: 48),
                                const SizedBox(height: 12),
                                const Text(
                                  "Engine Up-To-Date",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  state.message ?? "Running stable production baseline.",
                                  style: const TextStyle(color: Colors.white60),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.shield_outlined, color: Colors.white38, size: 48),
                              SizedBox(height: 12),
                              Text(
                                "OTA Engine Initialized",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Manual Check Action Button
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<OtaBloc>().add(CheckForUpdatesEvent());
                  },
                  icon: const Icon(Icons.cloud_download),
                  label: const Text(
                    "Check Server Remote Config",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color accentColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
