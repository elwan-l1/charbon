import SwiftUI

/// A card to pick one of a few options.
///
/// The picked one has a thick ember outline and a tick.
struct ChoiceCard<Content: View>: View {
  let title: String
  var subtitle: String?
  let isSelected: Bool
  let action: () -> Void
  @ViewBuilder let content: Content
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 10) {
        content
        HStack(alignment: .top, spacing: 6) {
          VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.readingStrong)
            if let subtitle {
              Text(subtitle).font(.note).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          Spacer(minLength: 0)
          if isSelected {
            Image(systemName: "checkmark.square.fill").foregroundStyle(Theme.ember)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(
        Rectangle().outlined(
          fill: isHovering && !isSelected ? Theme.paper : Theme.surface,
          line: isSelected ? Theme.ember : Theme.line,
          width: isSelected ? 3.5 : Theme.stroke
        )
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// A row of options of which one is picked.
struct Segmented<Value: Hashable>: View {
  let options: [(Value, String)]
  @Binding var selection: Value

  var body: some View {
    HStack(spacing: 8) {
      ForEach(Array(options.enumerated()), id: \.offset) { _, option in
        let isSelected = selection == option.0
        Button {
          selection = option.0
        } label: {
          Text(option.1)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(isSelected ? Theme.paper : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
              Rectangle().outlined(fill: isSelected ? Theme.ink : Theme.surface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
  }
}

/// A switch with a cut track and a cut knob.
struct BlockToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      HStack(spacing: 14) {
        configuration.label
        Spacer(minLength: 12)
        ZStack(alignment: configuration.isOn ? .trailing : .leading) {
          Rectangle().outlined(fill: configuration.isOn ? Theme.ink : Theme.surface)
          Rectangle().fill(configuration.isOn ? Theme.paper : Theme.ink)
            .frame(width: 20, height: 20).padding(.horizontal, 5)
        }
        .frame(width: 56, height: 30)
        Text(configuration.isOn ? "On" : "Off")
          .font(.system(size: 12, weight: .heavy)).frame(width: 24, alignment: .leading)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(.isButton)
    .accessibilityValue(configuration.isOn ? "On" : "Off")
  }
}

extension View {
  /// The box around a text field: cut corners and the thick outline.
  func flatField(width: CGFloat = 120) -> some View {
    self
      .textFieldStyle(.plain)
      .font(.figure(15, weight: .semibold))
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(width: width)
      .background(Rectangle().outlined())
  }
}

/// A number with a button on each side to change it by a step.
struct NumberStepper: View {
  @Binding var value: Double
  let step: Double
  let range: ClosedRange<Double>
  let format: (Double) -> String

  var body: some View {
    HStack(spacing: 10) {
      Button {
        value = max(range.lowerBound, value - step)
      } label: {
        Image(systemName: "minus").frame(width: 14)
      }
      .buttonStyle(.block)
      .disabled(value <= range.lowerBound)
      .accessibilityLabel("Less")
      Text(format(value)).font(.figure(18, weight: .heavy)).frame(minWidth: 76)
      Button {
        value = min(range.upperBound, value + step)
      } label: {
        Image(systemName: "plus").frame(width: 14)
      }
      .buttonStyle(.block)
      .disabled(value >= range.upperBound)
      .accessibilityLabel("More")
    }
  }
}
