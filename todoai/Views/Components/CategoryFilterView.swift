import SwiftUI

struct CategoryFilterView: View {
    let categories: [CategoryModel]
    let selectedCategory: CategoryModel?
    let onCategorySelected: (CategoryModel?) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All tasks button
                CategoryFilterChip(
                    title: "All",
                    icon: "list.bullet",
                    color: .blue,
                    isSelected: selectedCategory == nil
                ) {
                    onCategorySelected(nil)
                }
                
                // Category buttons
                ForEach(categories) { category in
                    CategoryFilterChip(
                        title: category.name,
                        icon: category.icon,
                        color: Color(hex: category.color),
                        isSelected: selectedCategory?.id == category.id
                    ) {
                        onCategorySelected(category)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct CategoryFilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : color.opacity(0.1))
            .foregroundColor(isSelected ? .white : color)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let categories = CategoryModel.createDefaultCategories()
    
    return CategoryFilterView(
        categories: categories,
        selectedCategory: nil,
        onCategorySelected: { _ in }
    )
} 