import AppKit
import SwiftUI

struct TaskBoardPanelView: View {
    static let preferredWidth: CGFloat = 540
    static func height(for count: Int) -> CGFloat { min(620, max(110, 70 + CGFloat(count) * 54)) }

    let tasks: [BoardTask]
    let width: CGFloat
    let height: CGFloat
    let open: (String, Date) -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tasks")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("\(tasks.count)")
                    .foregroundStyle(.gray)
                Button("Close", action: dismiss)
                    .buttonStyle(.plain)
                    .foregroundStyle(.gray)
                    .padding(.leading, 10)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            if tasks.isEmpty {
                Text("No active tasks")
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 18)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(tasks) { task in
                            Button { open(task.id, task.updatedAt) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(task.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(task.updatedAt, format: .dateTime.day().month(.abbreviated).year())
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.white.opacity(0.52))
                                            .fixedSize()
                                    }
                                    progress(task)
                                        .frame(height: 20)
                                }
                                .padding(.horizontal, 18)
                                .frame(height: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(task.title), updated \(task.updatedAt.formatted(date: .abbreviated, time: .omitted)), \(task.completed) of \(task.total) complete, \(task.signal.rawValue)")
                            Divider().overlay(Color.white.opacity(0.12)).padding(.horizontal, 18)
                        }
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .frame(width: width, height: height)
        .background(Color(red: 0.12, green: 0.12, blue: 0.13),
                    in: RoundedRectangle(cornerRadius: 19))
        .environment(\.colorScheme, .dark)
    }

    private func progress(_ task: BoardTask) -> some View {
        let fraction = CGFloat(task.completed) / CGFloat(task.total)
        return ZStack {
            Capsule().fill(Color.white.opacity(0.25)).frame(height: 7)
            GeometryReader { geometry in
                Capsule()
                    .fill(Color(red: 0.84, green: 0.65, blue: 0.13))
                    .frame(width: geometry.size.width * fraction, height: 7)
                    .position(x: geometry.size.width * fraction / 2, y: geometry.size.height / 2)
            }
            GeometryReader { geometry in
                if task.signal != .none {
                    Image(systemName: symbol(task.signal))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color(task.signal))
                        .shadow(color: .black, radius: 2)
                        .position(x: max(9, min(geometry.size.width - 9,
                                              geometry.size.width * fraction)),
                                  y: geometry.size.height / 2)
                }
            }
        }
    }

    private func symbol(_ signal: TaskSignal) -> String {
        switch signal {
        case .none: return ""
        case .problem, .blocked: return "exclamationmark.triangle.fill"
        case .needs_user: return "person.crop.circle.fill"
        case .paused: return "pause.circle.fill"
        }
    }

    private func color(_ signal: TaskSignal) -> Color {
        switch signal {
        case .none: return .clear
        case .problem: return .yellow
        case .blocked: return .red
        case .needs_user: return .orange
        case .paused: return .gray
        }
    }
}
