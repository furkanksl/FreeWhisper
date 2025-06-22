import SwiftUI

struct SettingsSidebar: View {
    @Binding var selectedCategory: SettingsCategory
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.linearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("FreeWhisper")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            // Navigation
            List(SettingsCategory.allCases, id: \.self, selection: $selectedCategory) { category in
                SidebarRow(
                    category: category,
                    isSelected: selectedCategory == category
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Divider()
                    .padding(.horizontal, 16)
                
                HStack {
                    Text("v0.0.7")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        // Open about or help
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.controlBackgroundColor))
        .frame(width: 240)
    }
}

struct SidebarRow: View {
    let category: SettingsCategory
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white  : Color.gray)
                    .frame(width: 28, height: 28)
                
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .white)
            }
            
            Text(category.fullName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.clear)
        )
        .contentShape(Rectangle())
    }
} 
