import AppKit
import SwiftUI

struct TaskBoardPanelView: View {
    static let preferredWidth: CGFloat = 540
    static func height(for count: Int) -> CGFloat { min(620, max(150, 112 + CGFloat(count) * 54)) }

    let tasks: [BoardTask]
    let selectedSubstatus: TaskSubstatus?
    let width: CGFloat
    let height: CGFloat
    let selectSubstatus: (TaskSubstatus?) -> Void
    let open: (String, Date) -> Void
    let dismiss: () -> Void

    private var visibleTasks: [BoardTask] {
        guard let selectedSubstatus else { return tasks }
        return tasks.filter { $0.substatus == selectedSubstatus }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Zadania")
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
            .padding(.top, 14)
            .padding(.bottom, 8)

            Rectangle().fill(Color.white.opacity(0.18)).frame(height: 1)
                .padding(.horizontal, 18)

            HStack(spacing: 0) {
                tab("Wszystkie", count: tasks.count, selected: selectedSubstatus == nil) {
                    selectSubstatus(nil)
                }
                ForEach(TaskSubstatus.allCases, id: \.self) { substatus in
                    tab(substatus.title,
                        count: tasks.filter { $0.substatus == substatus }.count,
                        selected: selectedSubstatus == substatus) {
                        selectSubstatus(substatus)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 5)

            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                .padding(.horizontal, 18)

            if visibleTasks.isEmpty {
                Text("Brak aktywnych zadań")
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleTasks) { task in
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
                                    HStack(spacing: 0) {
                                        Spacer(minLength: 0)
                                        progress(task)
                                            .frame(width: max(120, (width - 36) * 0.53), height: 20)
                                    }
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

    private func tab(_ title: String, count: Int, selected: Bool,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text(title).lineLimit(1)
                    Text("\(count)")
                        .foregroundStyle(selected ? Color(red: 0.84, green: 0.65, blue: 0.13)
                                         : Color.white.opacity(0.48))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                Rectangle()
                    .fill(selected ? Color(red: 0.84, green: 0.65, blue: 0.13) : .clear)
                    .frame(height: 3)
            }
            .font(.system(size: 11, weight: selected ? .semibold : .medium))
            .frame(maxWidth: .infinity)
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.55))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) active tasks")
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
