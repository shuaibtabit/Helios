import SwiftUI

// MARK: - DataCenter Status Overlay

struct DataCenterStatusOverlay: View {
    let inventory: DataCenterInventory?
    let useMockData: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if useMockData {
                HStack(spacing: 4) {
                    Image(systemName: "globe.badge.chevron.backward")
                        .font(.caption2)
                    Text("MOCK")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(4)
            }

            if let inventory = inventory {
                HStack(spacing: 6) {
                    if inventory.criticalDevices > 0 {
                        StatusBadge(
                            count: inventory.criticalDevices,
                            color: .red,
                            label: "Critical"
                        )
                    }

                    if inventory.degradedDevices > 0 {
                        StatusBadge(
                            count: inventory.degradedDevices,
                            color: .orange,
                            label: "Degraded"
                        )
                    }

                    if inventory.offlineDevices > 0 {
                        StatusBadge(
                            count: inventory.offlineDevices,
                            color: .gray,
                            label: "Offline"
                        )
                    }

                    if inventory.criticalDevices == 0 &&
                       inventory.degradedDevices == 0 &&
                       inventory.offlineDevices == 0 {
                        StatusBadge(
                            count: inventory.healthyDevices,
                            color: .green,
                            label: "Healthy"
                        )
                    }
                }
            }
        }
        .padding(8)
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let count: Int
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text("\(count)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))

            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .foregroundColor(.white)
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Mock Mode + All Healthy")
        DataCenterStatusOverlay(
            inventory: MockDataCenterScenarios.generateInventory(scenario: .healthy),
            useMockData: true
        )

        Text("Critical Issues")
        DataCenterStatusOverlay(
            inventory: MockDataCenterScenarios.generateInventory(scenario: .criticalTemperature),
            useMockData: false
        )

        Text("Mixed Health")
        DataCenterStatusOverlay(
            inventory: MockDataCenterScenarios.generateInventory(scenario: .mixedHealth),
            useMockData: true
        )

        Text("No Inventory")
        DataCenterStatusOverlay(
            inventory: nil,
            useMockData: false
        )
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.3))
}
