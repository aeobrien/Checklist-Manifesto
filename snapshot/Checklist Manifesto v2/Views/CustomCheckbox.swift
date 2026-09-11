import SwiftUI

struct CustomCheckbox: View {
    let isChecked: Bool
    let action: () -> Void
    let size: CGFloat = 24
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isChecked ? Theme.checkboxFilled : Theme.checkboxBorder, lineWidth: 2)
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isChecked ? Theme.checkboxFilled : Color.clear)
                    )
                
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.6, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isChecked)
    }
}

struct CheckboxPair: View {
    let firstChecked: Bool
    let secondChecked: Bool
    let onFirstTap: () -> Void
    let onSecondTap: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.smallSpacing) {
            CustomCheckbox(isChecked: firstChecked, action: onFirstTap)
            CustomCheckbox(isChecked: secondChecked, action: onSecondTap)
        }
    }
}