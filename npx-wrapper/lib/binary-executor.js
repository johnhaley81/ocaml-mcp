/**
 * Binary Executor - TDD Implementation (GREEN Phase)
 * 
 * Minimal implementation to pass all test scenarios.
 * Command execution: opam exec -- ocaml-mcp-server [args]
 */

import { spawn } from 'child_process';

export class BinaryExecutor {
  constructor(spawnFunction = spawn) {
    this.spawn = spawnFunction;
  }

  async executeServer(serverArgs) {
    return new Promise((resolve) => {
      // Construct command: opam exec -- ocaml-mcp-server [serverArgs...]
      const command = 'opam';
      const args = ['exec', '--', 'ocaml-mcp-server', ...serverArgs];
      const options = { stdio: 'inherit' };

      // Spawn the child process
      const child = this.spawn(command, args, options);

      // Signal handlers for forwarding SIGINT/SIGTERM to child
      const signalHandler = (signal) => {
        if (child.kill) {
          child.kill(signal);
        }
      };

      // Set up signal forwarding
      child.on('SIGINT', () => signalHandler('SIGINT'));
      child.on('SIGTERM', () => signalHandler('SIGTERM'));

      // Handle child process exit
      child.on('exit', (code, signal) => {
        // Clean up signal handlers
        child.off('SIGINT', signalHandler);
        child.off('SIGTERM', signalHandler);

        let exitCode;
        
        if (signal) {
          // Process terminated by signal - convert to exit code
          if (signal === 'SIGINT') {
            exitCode = 130; // 128 + 2
          } else if (signal === 'SIGTERM') {
            exitCode = 143; // 128 + 15
          } else if (signal === 'SIGSEGV') {
            exitCode = 139; // 128 + 11
          } else {
            // Default signal exit code
            exitCode = 128 + (this.getSignalNumber(signal) || 1);
          }
        } else {
          // Process exited normally - use the exit code
          exitCode = code;
        }

        resolve(exitCode);
      });

      // Handle spawn errors
      child.on('error', (error) => {
        // Clean up signal handlers on error
        child.off('SIGINT', signalHandler);
        child.off('SIGTERM', signalHandler);

        let exitCode;
        
        if (error.code === 'ENOENT') {
          // Command not found
          exitCode = 127;
        } else if (error.code === 'EACCES') {
          // Permission denied
          exitCode = 126;
        } else {
          // General error
          exitCode = 1;
        }

        resolve(exitCode);
      });
    });
  }

  // Helper method to get signal numbers for exit code calculation
  getSignalNumber(signal) {
    const signalNumbers = {
      'SIGINT': 2,
      'SIGTERM': 15,
      'SIGSEGV': 11,
      'SIGKILL': 9,
      'SIGQUIT': 3
    };
    return signalNumbers[signal] || 1;
  }
}