import SwiftUI
import KeyVoxCore

extension SettingsView {
    struct LegalView: View {
        @Environment(\.dismiss) var dismiss

        private var pronunciationLicensesText: String {
            KeyVoxCoreResourceText.pronunciationLicensesText
                ?? "Pronunciation third-party attributions are bundled in the KeyVoxCore package resources."
        }

        private var projectLicenseText: String {
            bundledText(
                fileName: "LICENSE",
                fileExtension: "md",
                fallback: "Unable to load bundled project license."
            )
        }

        private var oflText: String {
            bundledText(
                fileName: "OFL",
                fileExtension: "txt",
                fallback: "Unable to load bundled OFL text."
            )
        }

        private var thirdPartyNoticesText: String {
            bundledText(
                fileName: "THIRD_PARTY_NOTICES",
                fileExtension: "md",
                fallback: "Unable to load bundled third-party notices."
            )
        }

        private func bundledText(
            fileName: String,
            fileExtension: String,
            subdirectory: String? = nil,
            fallback: String
        ) -> String {
            guard let url = Bundle.main.url(
                forResource: fileName,
                withExtension: fileExtension,
                subdirectory: subdirectory
            ) else {
                return fallback
            }

            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return fallback
            }

            return content
        }
        
        var body: some View {
            ZStack {
                // Background Layer: Dark Indigo
                MacAppTheme.screenBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Legal & Licenses")
                            .font(.appFont(18))
                            .foregroundColor(MacAppTheme.accent)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(MacAppTheme.closeButtonForeground)
                        }
                        .buttonStyle(.plain)
                        .offset(y: -5)
                    }
                    .padding(20)
                    .background(MacAppTheme.cardFill)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(MacAppTheme.cardStroke),
                        alignment: .bottom
                    )
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            LicenseGroup(
                                title: "KeyVox",
                                copyright: "Copyright (c) 2026 Dominic Esposito",
                                license: projectLicenseText
                            )
                            
                            LicenseGroup(
                                title: "whisper.cpp",
                                copyright: "Copyright (c) The ggml authors",
                                license: """
    MIT License
    
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """
                            )
                            
                            LicenseGroup(
                                title: "OpenAI Whisper Model",
                                copyright: "OpenAI",
                                license: """
    MIT License
    
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """
                            )

                            LicenseGroup(
                                title: "NVIDIA Parakeet Model",
                                copyright: "NVIDIA, with Apple-platform Core ML distribution via FluidInference",
                                license: """
    KeyVox optionally downloads Core ML artifacts derived from NVIDIA's `parakeet-tdt-0.6b-v3` multilingual automatic speech recognition model.

    Governing license: CC BY 4.0
    Upstream model: https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
    Core ML distribution used by KeyVox: https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml

    The bundled Third-Party Notices section below is the authoritative attribution record for downloaded model artifacts.
    """
                            )
                            
                            LicenseGroup(
                                title: "Kanit Font",
                                copyright: "Copyright 2015 Cadson Demak",
                                license: oflText
                            )

                            LicenseGroup(
                                title: "Pronunciation Data (CMUdict + SCOWL)",
                                copyright: "Third-party data attributions",
                                license: pronunciationLicensesText
                            )

                            LicenseGroup(
                                title: "Third-Party Notices (Authoritative)",
                                copyright: "Bundled notice index",
                                license: thirdPartyNoticesText
                            )
                        }
                        .padding(24)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
            .frame(width: 500, height: 600)
        }
    }

    private struct LicenseGroup: View {
        let title: String
        let copyright: String
        let license: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.appFont(16))
                    .foregroundColor(.white)
                
                Text(copyright)
                    .font(.appFont(12))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(license)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(12)
                    .background(MacAppTheme.cardFill)
                    .cornerRadius(8)
            }
        }
    }
}
