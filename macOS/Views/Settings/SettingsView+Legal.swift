import Foundation
import SwiftUI
import KeyVoxCore

extension SettingsView {
    struct LegalView: View {
        @Environment(\.dismiss) var dismiss

        private var pronunciationLicensesText: String {
            KeyVoxCoreResourceText.pronunciationLicensesText
                ?? String(localized: "Pronunciation third-party attributions are bundled in the KeyVoxCore package resources.", comment: "Fallback text in the Legal & Licenses window in Settings when the pronunciation data attributions cannot be loaded. KeyVoxCore is a package name and stays in English.")
        }

        private var projectLicenseText: String {
            bundledText(
                fileName: "LICENSE",
                fileExtension: "md",
                fallback: String(localized: "Unable to load bundled project license.", comment: "Fallback text in the Legal & Licenses window in Settings when the KeyVox license file cannot be loaded.")
            )
        }

        private var oflText: String {
            bundledText(
                fileName: "OFL",
                fileExtension: "txt",
                fallback: String(localized: "Unable to load bundled OFL text.", comment: "Fallback text in the Legal & Licenses window in Settings when the font license file cannot be loaded. OFL is the SIL Open Font License and stays as written.")
            )
        }

        private var thirdPartyNoticesText: String {
            bundledText(
                fileName: "THIRD_PARTY_NOTICES",
                fileExtension: "md",
                fallback: String(localized: "Unable to load bundled third-party notices.", comment: "Fallback text in the Legal & Licenses window in Settings when the third-party notices file cannot be loaded.")
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
                        Text("Legal & Licenses", comment: "Title of the Legal & Licenses window in Settings.")
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
                                title: String(localized: "OpenAI Whisper Model", comment: "Section title in the Legal & Licenses window in Settings for the Whisper speech model license. OpenAI Whisper is a brand name and stays in English."),
                                copyright: "OpenAI",
                                license: """
    MIT License
    
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """
                            )

                            LicenseGroup(
                                title: String(localized: "NVIDIA Parakeet Model", comment: "Section title in the Legal & Licenses window in Settings for the Parakeet speech model license. NVIDIA Parakeet is a brand name and stays in English."),
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
                                title: String(localized: "Kanit Font", comment: "Section title in the Legal & Licenses window in Settings for the Kanit font license. Kanit is a font name and stays in English."),
                                copyright: "Copyright 2015 Cadson Demak",
                                license: oflText
                            )

                            LicenseGroup(
                                title: String(localized: "Pronunciation Data (CMUdict + SCOWL)", comment: "Section title in the Legal & Licenses window in Settings for pronunciation data licenses. CMUdict and SCOWL are data set names and stay in English."),
                                copyright: String(localized: "Third-party data attributions", comment: "Subtitle of the pronunciation data section in the Legal & Licenses window in Settings."),
                                license: pronunciationLicensesText
                            )

                            LicenseGroup(
                                title: String(localized: "Third-Party Notices (Authoritative)", comment: "Section title in the Legal & Licenses window in Settings for the full list of third-party notices."),
                                copyright: String(localized: "Bundled notice index", comment: "Subtitle of the third-party notices section in the Legal & Licenses window in Settings."),
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
