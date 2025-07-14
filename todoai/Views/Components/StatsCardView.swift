import SwiftUI

struct StatsCardView: View {
    let todayCount: Int
    let overdueCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Today",
                count: todayCount,
                color: .blue,
                icon: "sun.max"
            )
            
            StatCard(
                title: "Overdue",
                count: overdueCount,
                color: .red,
                icon: "clock.badge.exclamationmark"
            )
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    StatsCardView(todayCount: 5, overdueCount: 2)
        .padding()
} 