import SwiftUI

extension SettingsView {
    var sidebarView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            AnimatedWaveHeader()
                .padding(.top, 35)
                .padding(.bottom, 24)
            
            // Navigation Items
            ForEach(SettingsTab.allCases) { tab in
                SidebarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, -8)
        .padding(.bottom, 24)
        .frame(width: 260)
        .background(MacAppTheme.sidebarFill)
    }
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
