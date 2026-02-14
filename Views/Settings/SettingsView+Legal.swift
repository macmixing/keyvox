import SwiftUI

extension SettingsView {
    struct LegalView: View {
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            ZStack {
                // Background Layer: Dark Indigo
                Color.indigo.opacity(0.15)
                    .background(Color(white: 0.01))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Legal & Licenses")
                            .font(.custom("Kanit Medium", size: 18))
                            .foregroundColor(.indigo)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .offset(y: -5)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.white.opacity(0.1)),
                        alignment: .bottom
                    )
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            LicenseGroup(
                                title: "KeyVox",
                                copyright: "Copyright (c) 2026 Dominic Esposito",
                                license: """
    Source Code License (MIT)
    
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    
    ---
    Excluded Proprietary Assets and Branding
    
    The MIT License applies to all source code in this repository except for the files and assets explicitly listed below.
    
    The following files and assets are NOT licensed under the MIT License and remain the exclusive property of Dominic Esposito. They may not be used, copied, modified, or redistributed in any commercial or public-facing project without explicit written permission.
    
    Excluded Files and Assets
    
    1. Resources/Assets.xcassets/
       Includes all App Icons, the KeyVox logo, and related brand imagery.
    
    2. Views/Components/KeyVoxLogo.swift
       The proprietary implementation of the KeyVox logo.
    
    3. Views/RecordingOverlay.swift
       The proprietary "Audio-Reactive Wave" animation, which is a derivative of the KeyVox brand identity.
    
    4. Resources/keyvox.icon/
       The proprietary app icon package and source imagery.
    
    5. Resources/logo.png
       The standalone KeyVox logo artwork used in repository branding.
    
    These visual elements represent the unique brand identity of KeyVox and are reserved for current and future commercial use.
    
    ---
    
    Condition of Redistribution
    
    You are free to use, study, modify, and commercially distribute the MIT-licensed source code in this repository.
    
    However, if you fork or redistribute this project, you must remove all excluded proprietary assets listed above and replace them with your own original branding, including:
    
    - A unique application name
    - A unique icon
    - A distinct visual identity
    
    Your fork may not use branding, visual elements, or design elements that could reasonably be confused with KeyVox.
    
    ---

    Trademark Notice:
    "KeyVox", its logos, and related brand elements are reserved.
    This license does not grant any rights to use the KeyVox name or marks in a manner that suggests affiliation, endorsement, or origin.
    """
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
                                title: "Kanit Font",
                                copyright: "Copyright 2015 Cadson Demak",
                                license: """
    SIL Open Font License (OFL)
    
    PREAMBLE
    The goals of the Open Font License (OFL) are to stimulate worldwide development of collaborative font projects, to support the font creation efforts of academic and linguistic communities, and to provide a free and open framework in which fonts may be shared and improved in partnership with others.
    
    The OFL allows the licensed fonts to be used, studied, modified and redistributed freely as long as they are not sold by themselves. The fonts, including any derivative works, can be bundled, embedded, redistributed and/or sold with any software provided that any reserved names are not used by derivative works. The fonts and derivatives, however, cannot be released under any other type of license. The requirement for fonts to remain under this license does not apply to any document created using the fonts or their derivatives.
    """
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
                    .font(.custom("Kanit Medium", size: 16))
                    .foregroundColor(.white)
                
                Text(copyright)
                    .font(.custom("Kanit Medium", size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(license)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
}
