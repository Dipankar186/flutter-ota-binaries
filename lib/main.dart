import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'ota/bloc/ota_bloc.dart';
import 'firebase_options.dart'; // 👈 2. Yeh auto-generated file import honi chahiye
import 'ota/bloc/ota_event.dart';
import 'ota/bloc/ota_state.dart';
import 'ota/service/native_bridge.dart';
import 'firebase_options.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // Firebase configuration link karo
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Free Firebase Environment
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
        )..add(CheckForUpdatesEvent()), // App open hote hi automatic check trigger
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red, // 🔵 Base Version 1 screen color
      body: BlocListener<OtaBloc, OtaState>(
        listener: (context, state) {
          if (state is OtaDownloadingState) {
            print("LOG: Downloading background bytes... ${state.progress.toStringAsFixed(1)}%");
          }
          if (state is OtaUpdateStagedSuccess) {
            print("🎉 SUCCESS: Binary safely swapped! Next restart will boot V2.");
          }
          if (state is OtaRollbackErrorState) {
            print("🚨 ROLLBACK: ${state.message}");
          }
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Version 2.0 (Stable Base Code)",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              BlocBuilder<OtaBloc, OtaState>(
                builder: (context, state) {
                  if (state is OtaCheckingState) {
                    return const Text("Checking remote configs...", style: TextStyle(color: Colors.white70));
                  }
                  if (state is OtaDownloadingState) {
                    return Text(
                      "Downloading dynamic patch: ${state.progress.toStringAsFixed(0)}%",
                      style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w500),
                    );
                  }
                  if (state is OtaUpdateStagedSuccess) {
                    return const Text("🟢 Patch ready! Restart app to apply.", style: TextStyle(color: Colors.greenAccent));
                  }
                  if (state is OtaRollbackErrorState) {
                    return Text("⚠️ Engine Safe: ${state.message}", style: const TextStyle(color: Colors.orangeAccent), textAlign: TextAlign.center);
                  }
                  return const Text("Status: Up to date & Stable", style: TextStyle(color: Colors.white60));
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
