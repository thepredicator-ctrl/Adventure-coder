import Foundation

/// Additional project templates for more languages and frameworks.
public enum AdvancedTemplates {
    /// Flutter project template
    public static func flutterFiles(name: String) -> [(String, String)] {
        return [
            ("pubspec.yaml", """
            name: \(name.lowercased())
            description: A Flutter app built with Adventure Coder.
            publish_to: 'none'
            version: 1.0.0+1

            environment:
              sdk: '>=3.0.0 <4.0.0'

            dependencies:
              flutter:
                sdk: flutter
              cupertino_icons: ^1.0.6

            dev_dependencies:
              flutter_test:
                sdk: flutter
              flutter_lints: ^3.0.0

            flutter:
              uses-material-design: true
            """),
            ("lib/main.dart", """
            import 'package:flutter/material.dart';

            void main() {
              runApp(const \(name.pascalCase)App());
            }

            class \(name.pascalCase)App extends StatelessWidget {
              const \(name.pascalCase)App({super.key});

              @override
              Widget build(BuildContext context) {
                return MaterialApp(
                  title: '\(name)',
                  theme: ThemeData(
                    colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
                    useMaterial3: true,
                  ),
                  home: const HomePage(),
                );
              }
            }

            class HomePage extends StatelessWidget {
              const HomePage({super.key});

              @override
              Widget build(BuildContext context) {
                return Scaffold(
                  appBar: AppBar(title: const Text('\(name)')),
                  body: const Center(
                    child: Text('Built with Adventure Coder'),
                  ),
                );
              }
            }
            """),
            ("README.md", "# \(name)\n\nA Flutter app built with Adventure Coder.\n")
        ]
    }

    /// Kotlin project template
    public static func kotlinFiles(name: String) -> [(String, String)] {
        return [
            ("build.gradle.kts", """
            plugins {
                kotlin("jvm") version "1.9.22"
                application
            }

            group = "com.adventurecoder"
            version = "1.0.0"

            repositories {
                mavenCentral()
            }

            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
                testImplementation(kotlin("test"))
            }

            application {
                mainClass.set("com.adventurecoder.\(name.lowercased()).MainKt")
            }
            """),
            ("src/main/kotlin/com/adventurecoder/\(name.lowercased())/Main.kt", """
            package com.adventurecoder.\(name.lowercased())

            fun main() {
                println("\(name) ready")
            }
            """),
            ("README.md", "# \(name)\n\nA Kotlin app built with Adventure Coder.\n")
        ]
    }

    /// Go project template
    public static func goFiles(name: String) -> [(String, String)] {
        return [
            ("go.mod", """
            module \(name.lowercased())

            go 1.21
            """),
            ("main.go", """
            package main

            import "fmt"

            func main() {
                fmt.Println("\(name) ready")
            }
            """),
            ("README.md", "# \(name)\n\nA Go app built with Adventure Coder.\n")
        ]
    }

    /// Java project template
    public static func javaFiles(name: String) -> [(String, String)] {
        let pkg = name.lowercased().replacingOccurrences(of: " ", with: "_")
        return [
            ("pom.xml", """
            <?xml version="1.0" encoding="UTF-8"?>
            <project xmlns="http://maven.apache.org/POM/4.0.0">
                <modelVersion>4.0.0</modelVersion>
                <groupId>com.adventurecoder</groupId>
                <artifactId>\(pkg)</artifactId>
                <version>1.0.0</version>
                <properties>
                    <maven.compiler.source>17</maven.compiler.source>
                    <maven.compiler.target>17</maven.compiler.target>
                </properties>
            </project>
            """),
            ("src/main/java/com/adventurecoder/\(pkg)/Main.java", """
            package com.adventurecoder.\(pkg);

            public class Main {
                public static void main(String[] args) {
                    System.out.println("\(name) ready");
                }
            }
            """),
            ("README.md", "# \(name)\n\nA Java app built with Adventure Coder.\n")
        ]
    }

    /// C# project template
    public static func csharpFiles(name: String) -> [(String, String)] {
        return [
            ("\(name).csproj", """
            <Project Sdk="Microsoft.NET.Sdk">
              <PropertyGroup>
                <OutputType>Exe</OutputType>
                <TargetFramework>net8.0</TargetFramework>
                <ImplicitUsings>enable</ImplicitUsings>
                <Nullable>enable</Nullable>
              </PropertyGroup>
            </Project>
            """),
            ("Program.cs", """
            using System;

            class Program
            {
                static void Main(string[] args)
                {
                    Console.WriteLine("\(name) ready");
                }
            }
            """),
            ("README.md", "# \(name)\n\nA C# app built with Adventure Coder.\n")
        ]
    }

    /// Vue project template
    public static func vueFiles(name: String) -> [(String, String)] {
        return [
            ("package.json", """
            {
              "name": "\(name.lowercased())",
              "version": "0.0.0",
              "type": "module",
              "scripts": {
                "dev": "vite --host 0.0.0.0",
                "build": "vite build",
                "preview": "vite preview --host 0.0.0.0"
              },
              "dependencies": {
                "vue": "^3.4.0"
              },
              "devDependencies": {
                "@vitejs/plugin-vue": "^5.0.0",
                "typescript": "^5.3.0",
                "vite": "^5.0.0"
              }
            }
            """),
            ("vite.config.ts", """
            import { defineConfig } from 'vite'
            import vue from '@vitejs/plugin-vue'

            export default defineConfig({
              plugins: [vue()],
              server: { host: '0.0.0.0', port: 5173 }
            })
            """),
            ("index.html", """
            <!doctype html>
            <html lang="en">
              <head>
                <meta charset="UTF-8" />
                <title>\(name)</title>
              </head>
              <body>
                <div id="app"></div>
                <script type="module" src="/src/main.ts"></script>
              </body>
            </html>
            """),
            ("src/main.ts", """
            import { createApp } from 'vue'
            import App from './App.vue'

            createApp(App).mount('#app')
            """),
            ("src/App.vue", """
            <template>
              <main>
                <h1>\(name)</h1>
                <p>Built with Adventure Coder</p>
              </main>
            </template>

            <script setup lang="ts"></script>

            <style scoped>
            main { font-family: system-ui; padding: 24px; }
            </style>
            """),
            ("README.md", "# \(name)\n\nA Vue 3 app built with Adventure Coder.\n")
        ]
    }

    /// Svelte project template
    public static func svelteFiles(name: String) -> [(String, String)] {
        return [
            ("package.json", """
            {
              "name": "\(name.lowercased())",
              "version": "0.0.0",
              "type": "module",
              "scripts": {
                "dev": "vite dev --host 0.0.0.0",
                "build": "vite build",
                "preview": "vite preview --host 0.0.0.0"
              },
              "devDependencies": {
                "@sveltejs/kit": "^2.0.0",
                "svelte": "^5.0.0",
                "vite": "^5.0.0"
              }
            }
            """),
            ("src/routes/+page.svelte", """
            <script>
              let count = 0;
            </script>

            <main>
              <h1>\(name)</h1>
              <p>Built with Adventure Coder</p>
              <button on:click={() => count++}>Count: {count}</button>
            </main>
            """),
            ("README.md", "# \(name)\n\nA SvelteKit app built with Adventure Coder.\n")
        ]
    }

    /// Next.js project template
    public static func nextjsFiles(name: String) -> [(String, String)] {
        return [
            ("package.json", """
            {
              "name": "\(name.lowercased())",
              "version": "0.0.0",
              "scripts": {
                "dev": "next dev -H 0.0.0.0",
                "build": "next build",
                "start": "next start -H 0.0.0.0"
              },
              "dependencies": {
                "next": "^14.1.0",
                "react": "^18.3.0",
                "react-dom": "^18.3.0"
              },
              "devDependencies": {
                "@types/node": "^20.11.0",
                "@types/react": "^18.3.0",
                "typescript": "^5.3.0"
              }
            }
            """),
            ("app/layout.tsx", """
            import { Metadata } from 'next'

            export const metadata: Metadata = {
              title: '\(name)',
              description: 'Built with Adventure Coder'
            }

            export default function RootLayout({
              children,
            }: {
              children: React.ReactNode
            }) {
              return (
                <html lang="en">
                  <body>{children}</body>
                </html>
              )
            }
            """),
            ("app/page.tsx", """
            export default function Home() {
              return (
                <main style={{ fontFamily: 'system-ui', padding: 24 }}>
                  <h1>\(name)</h1>
                  <p>Built with Adventure Coder</p>
                </main>
              )
            }
            """),
            ("README.md", "# \(name)\n\nA Next.js 14 app built with Adventure Coder.\n")
        ]
    }

    /// Express.js project template
    public static func expressFiles(name: String) -> [(String, String)] {
        return [
            ("package.json", """
            {
              "name": "\(name.lowercased())",
              "version": "1.0.0",
              "type": "module",
              "main": "index.js",
              "scripts": {
                "start": "node index.js",
                "dev": "node --watch index.js"
              },
              "dependencies": {
                "express": "^4.18.2"
              }
            }
            """),
            ("index.js", """
            import express from 'express'

            const app = express()
            const PORT = process.env.PORT || 3000

            app.use(express.json())

            app.get('/', (req, res) => {
              res.json({ name: '\(name)', status: 'running' })
            })

            app.get('/health', (req, res) => {
              res.json({ status: 'ok' })
            })

            app.listen(PORT, '0.0.0.0', () => {
              console.log(`\(name) running on port ${PORT}`)
            })
            """),
            ("README.md", "# \(name)\n\nAn Express.js API built with Adventure Coder.\n")
        ]
    }

    /// Django project template
    public static func djangoFiles(name: String) -> [(String, String)] {
        return [
            ("requirements.txt", """
            Django>=5.0
            djangorestframework>=3.14
            """),
            ("manage.py", """
            #!/usr/bin/env python
            import os
            import sys

            if __name__ == '__main__':
                os.environ.setdefault('DJANGO_SETTINGS_MODULE', '\(name.lowercased()).settings')
                from django.core.management import execute_from_command_line
                execute_from_command_line(sys.argv)
            """),
            ("README.md", "# \(name)\n\nA Django app built with Adventure Coder.\n\n```bash\npython manage.py runserver 0.0.0.0:8000\n```\n")
        ]
    }

    /// FastAPI project template
    public static func fastapiFiles(name: String) -> [(String, String)] {
        return [
            ("requirements.txt", """
            fastapi>=0.109.0
            uvicorn[standard]>=0.27.0
            """),
            ("main.py", """
            from fastapi import FastAPI

            app = FastAPI(title="\(name)")

            @app.get("/")
            def read_root():
                return {"name": "\(name)", "status": "running"}

            @app.get("/health")
            def health():
                return {"status": "ok"}

            if __name__ == "__main__":
                import uvicorn
                uvicorn.run(app, host="0.0.0.0", port=8000)
            """),
            ("README.md", "# \(name)\n\nA FastAPI app built with Adventure Coder.\n\n```bash\nuvicorn main:app --host 0.0.0.0 --port 8000\n```\n")
        ]
    }

    /// Ruby on Rails project template
    public static func railsFiles(name: String) -> [(String, String)] {
        return [
            ("Gemfile", """
            source 'https://rubygems.org'

            ruby '3.2.0'

            gem 'rails', '~> 7.1.0'
            gem 'puma', '>= 5.0'
            gem 'sqlite3', '~> 1.4'
            """),
            ("README.md", "# \(name)\n\nA Ruby on Rails app built with Adventure Coder.\n\n```bash\nrails server -b 0.0.0.0\n```\n")
        ]
    }

    /// .NET MAUI project template
    public static func mauiFiles(name: String) -> [(String, String)] {
        return [
            ("\(name).csproj", """
            <Project Sdk="Microsoft.NET.Sdk.Razor">
              <PropertyGroup>
                <TargetFrameworks>net8.0-ios;net8.0-android</TargetFrameworks>
                <UseMaui>true</UseMaui>
                <SingleProject>true</SingleProject>
              </PropertyGroup>
            </Project>
            """),
            ("MainPage.xaml", """
            <?xml version="1.0" encoding="utf-8" ?>
            <ContentPage xmlns="http://schemas.microsoft.com/dotnet/2021/maui">
              <StackLayout>
                <Label Text="\(name)" FontSize="32" HorizontalOptions="Center" />
                <Label Text="Built with Adventure Coder" HorizontalOptions="Center" />
              </StackLayout>
            </ContentPage>
            """),
            ("README.md", "# \(name)\n\nA .NET MAUI app built with Adventure Coder.\n")
        ]
    }
}

private extension String {
    var pascalCase: String {
        let parts = split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return parts.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
    }
}
