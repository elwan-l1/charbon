import CharbonCore
import SwiftUI

/// The stamped periods of a day on a line from morning to evening, with the time now marked.
struct DayTimeline: View {
  let day: DayReport
  let now: ClockTime

  var body: some View {
    let range = visibleRange
    VStack(alignment: .leading, spacing: 8) {
      GeometryReader { proxy in
        ZStack(alignment: .topLeading) {
          Rectangle().fill(Theme.hairline)
          ForEach(blocks, id: \.start) { block in
            Rectangle()
              .fill(block.isOpen ? Theme.ember : Theme.ink)
              .frame(
                width: max(
                  position(block.end, range, proxy.size.width)
                    - position(block.start, range, proxy.size.width), 2)
              )
              .offset(x: position(block.start, range, proxy.size.width))
          }
          if day.isToday {
            Rectangle().fill(Theme.ember).frame(width: 2, height: proxy.size.height + 8)
              .offset(x: position(now.minutes, range, proxy.size.width) - 1, y: -4)
          }
        }
      }
      .frame(height: 28)
      .overlay(Rectangle().stroke(Theme.line, lineWidth: Theme.stroke))
      hourLabels(range)
    }
  }

  private struct Block {
    let start: Int
    let end: Int
    let isOpen: Bool
  }

  private var blocks: [Block] {
    day.day.filledPeriods.compactMap { period in
      guard let start = period.arrival.clockTime?.minutes else {
        return nil
      }
      if let end = period.departure.clockTime?.minutes {
        return Block(start: start, end: end, isOpen: false)
      }
      return day.isToday ? Block(start: start, end: max(now.minutes, start), isOpen: true) : nil
    }
  }

  private var visibleRange: ClosedRange<Int> {
    var first = 7 * 60
    var last = 19 * 60
    for block in blocks {
      first = min(first, block.start / 60 * 60)
      last = max(last, (block.end + 59) / 60 * 60)
    }
    if day.isToday {
      last = max(last, (now.minutes + 59) / 60 * 60)
    }
    return first...min(last, 24 * 60)
  }

  private func position(_ minutes: Int, _ range: ClosedRange<Int>, _ width: CGFloat) -> CGFloat {
    let span = CGFloat(range.upperBound - range.lowerBound)
    return width * CGFloat(min(max(minutes, range.lowerBound), range.upperBound) - range.lowerBound)
      / span
  }

  private func hourLabels(_ range: ClosedRange<Int>) -> some View {
    GeometryReader { proxy in
      ForEach(Array(stride(from: range.lowerBound, through: range.upperBound, by: 120)), id: \.self)
      {
        minutes in
        Text(String(format: "%02d", minutes / 60))
          .font(.figure(10, weight: .semibold))
          .foregroundStyle(Theme.muted)
          .position(x: position(minutes, range, proxy.size.width), y: 6)
      }
    }
    .frame(height: 12)
  }
}
