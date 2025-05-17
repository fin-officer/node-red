#!/bin/bash
# Skrypt startowy dla Email-LLM Integration
# Dla Linux/macOS
sudo lsof -i :8025
sudo lsof -i :11434

# Dla Windows (PowerShell)
netstat -ano | findstr :8025
netstat -ano | findstr :11434