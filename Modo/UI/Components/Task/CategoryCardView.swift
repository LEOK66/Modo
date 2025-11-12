import SwiftUI

/// Category card component for task form
struct CategoryCardView: View {
    @Binding var selectedCategory: TaskCategory?
    @Binding var dietEntries: [DietEntry]
    @Binding var fitnessEntries: [FitnessEntry]
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Category")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    categoryChip(.diet)
                    categoryChip(.fitness)
                    categoryChip(.others)
                }
                if selectedCategory == nil {
                    Text("Required")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "9CA3AF"))
                }
                // AI suggestions row (placeholder)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        aiSuggestionChip("Low-fat lunch 600 cal")
                        aiSuggestionChip("30m run after 7pm")
                        aiSuggestionChip("High-protein dinner")
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Color(hexString: "4A5565"))
    }
    
    private func categoryChip(_ category: TaskCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
            
            if category == .diet && dietEntries.isEmpty {
                dietEntries.append(DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
            } else if category == .fitness && fitnessEntries.isEmpty {
                fitnessEntries.append(FitnessEntry())
            }
        } label: {
            HStack(spacing: 8) {
                Text(category.rawValue)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hexString: "0A0A0A"))
            }
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color(hexString: "F3E8FF") : Color(hexString: "F9FAFB"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color(hexString: "C27AFF") : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
    }
    
    private func aiSuggestionChip(_ title: String) -> some View {
        Button(action: { /* placeholder */ }) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hexString: "101828"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hexString: "F3F4F6"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedCategory: TaskCategory? = nil
        @State private var dietEntries: [DietEntry] = []
        @State private var fitnessEntries: [FitnessEntry] = []
        
        var body: some View {
            CategoryCardView(
                selectedCategory: $selectedCategory,
                dietEntries: $dietEntries,
                fitnessEntries: $fitnessEntries
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}



