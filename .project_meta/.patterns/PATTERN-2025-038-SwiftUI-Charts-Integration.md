# PATTERN-2025-038: SwiftUI Charts Integration Pattern

## Pattern Information
- **ID**: PATTERN-2025-038
- **Name**: SwiftUI Charts Integration Pattern
- **Category**: UI Framework Integration
- **Difficulty**: Medium
- **Reusability**: High
- **Status**: ✅ Active
- **Source**: STORY-2025-010 Network Analytics Module
- **Extracted**: 2025-07-01

## Description
A specialized pattern for integrating Apple's Charts framework with SwiftUI applications, providing comprehensive guidelines for chart implementation, data binding, customization, and platform compatibility. This pattern ensures optimal performance and user experience when displaying complex data visualizations.

## Problem Statement
Integrating Charts framework with SwiftUI requires careful handling of data binding, chart configuration, platform-specific adaptations, and performance optimizations. Common challenges include proper data model design, chart responsiveness, accessibility support, and maintaining compatibility across different iOS versions.

## Solution Overview
The pattern provides a structured approach to Charts integration using wrapper components, data adapters, and configuration objects that abstract complex chart setup while maintaining flexibility for customization.

## Architecture Components

### 1. Chart Data Models
```swift
// Identifiable and Equatable data points
struct ChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let x: Double
    let y: Double
    let timestamp: Date
    let category: String
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.x == rhs.x && lhs.y == rhs.y
    }
}

// Chart configuration
struct ChartConfiguration {
    let chartType: ChartType
    let colorScheme: ChartColorScheme
    let animationEnabled: Bool
    let interactionEnabled: Bool
    let accessibilityEnabled: Bool
}
```

### 2. Chart Wrapper Components
```swift
// Reusable chart wrapper
struct AnalyticsChart: View {
    let data: [ChartDataPoint]
    let configuration: ChartConfiguration
    @State private var selectedPoint: ChartDataPoint?
    
    var body: some View {
        Chart(data) { point in
            createChartMark(for: point)
        }
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .onTapGesture { location in
                        selectPoint(at: location, geometry: geometry, proxy: chartProxy)
                    }
            }
        }
        .chartAngleSelection(value: .constant(nil))
        .accessibilityElement(children: .contain)
    }
}
```

### 3. Platform Adaptation Layer
```swift
// Platform-specific adaptations
extension AnalyticsChart {
    @ViewBuilder
    private func platformSpecificModifiers() -> some View {
        #if os(macOS)
        self.frame(minHeight: 300)
        #else
        self.frame(minHeight: 250)
            .background(Color(.systemBackground))
        #endif
    }
}
```

## Implementation Details

### Data Binding Best Practices
- Implement `Identifiable` and `Equatable` for chart data
- Use `@State` for local chart interactions
- Leverage `@Binding` for parent-child data flow
- Apply data transformation at the view model level

### Chart Types Support
- Line charts for time series data
- Bar charts for categorical comparisons
- Area charts for cumulative metrics
- Point charts for scatter plots
- Composite charts for multiple metrics

### Performance Optimization
- Data sampling for large datasets (>1000 points)
- Lazy loading for off-screen chart elements
- Efficient data updates with minimal re-rendering
- Memory management for real-time data streams

### Accessibility Implementation
- VoiceOver support for chart elements
- Haptic feedback for interactions
- High contrast mode compatibility
- Reduced motion preferences support

## Code Example

### Complete Chart Integration
```swift
import SwiftUI
import Charts

// Data model optimized for Charts
struct NetworkMetricPoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let bandwidth: Double
    let connections: Int
    let category: NetworkCategory
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && 
        lhs.timestamp == rhs.timestamp && 
        lhs.bandwidth == rhs.bandwidth
    }
}

// Chart configuration system
struct ChartStyle {
    static let primaryColor = Color.blue
    static let secondaryColor = Color.orange
    static let gridColor = Color.gray.opacity(0.3)
    static let backgroundColor = Color(.systemBackground)
}

// Reusable chart component
struct NetworkMetricsChart: View {
    let dataPoints: [NetworkMetricPoint]
    let chartType: NetworkChartType
    @State private var selectedTimestamp: Date?
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chart title and controls
            HStack {
                Text("Network Metrics")
                    .font(.headline)
                
                Spacer()
                
                ChartTypeSelector(selectedType: .constant(chartType))
            }
            
            // Main chart view
            Chart(dataPoints) { point in
                createChartElement(for: point)
            }
            .frame(height: 250)
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateSelection(at: value.location, 
                                                  geometry: geometry, 
                                                  proxy: chartProxy)
                                }
                        )
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(ChartStyle.gridColor)
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(ChartStyle.gridColor)
                    AxisValueLabel()
                }
            }
            .chartLegend(position: .bottom, alignment: .center) {
                HStack {
                    Label("Bandwidth", systemImage: "wifi")
                        .foregroundColor(ChartStyle.primaryColor)
                    Label("Connections", systemImage: "network")
                        .foregroundColor(ChartStyle.secondaryColor)
                }
                .font(.caption)
            }
            .animation(.easeInOut(duration: 0.3), value: dataPoints.count)
            
            // Selection details
            if let selectedTimestamp = selectedTimestamp,
               let selectedPoint = dataPoints.first(where: { $0.timestamp == selectedTimestamp }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected: \(selectedTimestamp, format: .dateTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Label("\(selectedPoint.bandwidth, format: .number) MB/s", 
                              systemImage: "wifi")
                        Label("\(selectedPoint.connections) connections", 
                              systemImage: "network")
                    }
                    .font(.caption2)
                }
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Network metrics chart showing bandwidth and connections over time")
    }
    
    @ViewBuilder
    private func createChartElement(for point: NetworkMetricPoint) -> some View {
        switch chartType {
        case .line:
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Bandwidth", point.bandwidth)
            )
            .foregroundStyle(ChartStyle.primaryColor)
            .symbol(by: .value("Type", "Bandwidth"))
            
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Connections", Double(point.connections))
            )
            .foregroundStyle(ChartStyle.secondaryColor)
            .symbol(by: .value("Type", "Connections"))
            
        case .area:
            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("Bandwidth", point.bandwidth)
            )
            .foregroundStyle(ChartStyle.primaryColor.opacity(0.6))
            
        case .bar:
            BarMark(
                x: .value("Time", point.timestamp),
                y: .value("Bandwidth", point.bandwidth)
            )
            .foregroundStyle(ChartStyle.primaryColor)
        }
    }
    
    private func updateSelection(at location: CGPoint, 
                               geometry: GeometryProxy, 
                               proxy: ChartProxy) {
        let xPosition = location.x - geometry[proxy.plotAreaFrame].origin.x
        let xValue = proxy.value(atX: xPosition, as: Date.self)
        
        if let xValue = xValue {
            selectedTimestamp = findNearestTimestamp(to: xValue)
        }
    }
    
    private func findNearestTimestamp(to target: Date) -> Date? {
        dataPoints.min { abs($0.timestamp.timeIntervalSince(target)) < abs($1.timestamp.timeIntervalSince(target)) }?.timestamp
    }
}

// Chart type enumeration
enum NetworkChartType: String, CaseIterable {
    case line = "Line"
    case area = "Area" 
    case bar = "Bar"
    
    var systemImage: String {
        switch self {
        case .line: return "chart.xyaxis.line"
        case .area: return "chart.line.uptrend.xyaxis"
        case .bar: return "chart.bar"
        }
    }
}

// Chart type selector component
struct ChartTypeSelector: View {
    @Binding var selectedType: NetworkChartType
    
    var body: some View {
        Picker("Chart Type", selection: $selectedType) {
            ForEach(NetworkChartType.allCases, id: \.self) { type in
                Label(type.rawValue, systemImage: type.systemImage)
                    .tag(type)
            }
        }
        .pickerStyle(.menu)
    }
}
```

## Benefits
1. **Native Integration**: Leverages Apple's optimized Charts framework
2. **Performance**: Hardware-accelerated rendering and animations
3. **Accessibility**: Built-in VoiceOver and accessibility support
4. **Customization**: Flexible styling and interaction options
5. **Platform Consistency**: Follows iOS/macOS design guidelines
6. **Future-Proof**: Supported by Apple with regular updates

## Trade-offs
1. **Platform Limitation**: iOS 16+ requirement
2. **Learning Curve**: New framework with specific API patterns
3. **Customization Limits**: Some advanced customizations not available
4. **Documentation**: Relatively new with evolving best practices

## Usage Guidelines
- Always implement `Identifiable` for chart data models
- Use `Equatable` for performance optimization with large datasets
- Implement proper accessibility labels and descriptions
- Test on different device sizes and orientations
- Consider data sampling for datasets larger than 1000 points
- Provide fallback for older iOS versions if needed

## Platform Compatibility
- **iOS**: 16.0+
- **macOS**: 13.0+
- **tvOS**: 16.0+
- **watchOS**: 9.0+

## Related Patterns
- PATTERN-2025-037: Real-time Analytics Visualization Pattern
- PATTERN-2025-035: SwiftUI Async State Management
- PATTERN-2025-039: Analytics State Management Pattern

## Testing Strategy
- Unit tests for data model transformations
- Snapshot tests for chart appearance
- Interaction tests for user gestures
- Accessibility tests for VoiceOver support
- Performance tests for large datasets

## Common Pitfalls
1. **Data Model Issues**: Forgetting to implement `Identifiable` or `Equatable`
2. **Performance Problems**: Not implementing data sampling for large datasets
3. **Accessibility Gaps**: Missing accessibility labels or descriptions
4. **Animation Issues**: Conflicting animations causing visual glitches
5. **Memory Leaks**: Retaining large datasets without proper cleanup

## Quality Metrics
- **Rendering Performance**: 60fps for smooth animations
- **Memory Usage**: Stable with data windowing
- **Accessibility Score**: 100% VoiceOver coverage
- **Code Coverage**: 90%+ for chart logic

---
*Extracted from STORY-2025-010: Network Analytics Module Integration*  
*Pattern validated with SwiftUI Charts framework best practices*
