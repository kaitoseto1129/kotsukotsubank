//
//  EditTaskView.swift
//  コツコツバンク
//

import SwiftUI

struct EditTaskView: View {
    @Bindable var mission: Mission
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var reward: String
    @State private var rewardUnit: RewardUnit
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(mission: Mission) {
        self.mission = mission
        _title = State(initialValue: mission.title)
        _reward = State(initialValue: String(Int(mission.reward)))
        _rewardUnit = State(initialValue: mission.rewardUnit)
        _hasDueDate = State(initialValue: mission.dueDate != nil)
        _dueDate = State(initialValue: mission.dueDate ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク内容") {
                    TextField("タスク名", text: $title)
                    TextField("タスク価格", text: $reward)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif

                    Picker("金額の単位", selection: $rewardUnit) {
                        ForEach(RewardUnit.allCases, id: \.self) { unit in
                            Text(LocalizedStringKey(unit.label)).tag(unit)
                        }
                    }
                }

                Section("期限") {
                    Toggle("期限を設定する", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("期限", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("タスクを編集")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(title.isEmpty || Double(reward) == nil)
                }
            }
            #endif
            .tint(ParentTheme.accent)
            .preferredColorScheme(.light)
        }
    }

    private func save() {
        guard let rewardValue = Double(reward) else { return }
        mission.title = title
        mission.reward = rewardValue
        mission.rewardUnit = rewardUnit
        mission.dueDate = hasDueDate ? dueDate : nil
        dismiss()
    }
}

#Preview {
    EditTaskView(mission: Mission(title: "お皿洗い", reward: 100, childID: UUID()))
}
