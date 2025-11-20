#!/bin/bash

# Script to set up and run the Strata SQLite example app

set -e  # Exit on any error

echo "🚀 Strata SQLite Example Setup"
echo "=============================="
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found"
    echo "Please run this script from the example directory"
    exit 1
fi

# Step 1: Install dependencies
echo "📦 Installing dependencies..."
dart pub get
echo "✓ Dependencies installed"
echo ""

# Step 2: Generate migrations
echo "📝 Generating migrations..."
dart run ../../strata_builder/bin/generate_migrations.dart
echo "✓ Migrations generated"
echo ""

# Step 3: Run code generation
echo "🔨 Running code generation..."
dart run build_runner build --delete-conflicting-outputs
echo "✓ Code generation complete"
echo ""

# Step 4: Run the example
echo "▶️  Running example app..."
echo ""
dart run main.dart

echo ""
echo "=============================="
echo "✨ Done!"
