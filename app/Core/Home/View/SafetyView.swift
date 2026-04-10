// app/Core/Home/View/SafetyView.swift
import SwiftUI

struct SafetyView: View {
    @EnvironmentObject var safety: SafetyManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: SOS button — big, prominent, center stage
                SOSCardView(safety: safety)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // MARK: Crash detection
                VStack(alignment: .leading, spacing: 0) {
                    Text("Automatic detection")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "car.side.and.exclamationmark")
                                .font(.system(size: 20))
                                .foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Crash detection")
                                .font(.body.weight(.medium))
                            Text("Powered by Apple SafetyKit — alerts your circle automatically on severe impact.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .opacity(0) // pending entitlement
                    }
                    .padding(16)
                    .background(Color(.secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }

                
            }
        }
        .navigationTitle("Safety")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - SOS card

struct SOSCardView: View {
    @ObservedObject var safety: SafetyManager

    var body: some View {
        VStack(spacing: 20) {
            switch safety.sosState {
            case .idle:
                idleState

            case .countdown(let secs):
                countdownState(secs: secs)

            case .active:
                activeState

            case .cancelled:
                cancelledState
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: cardShadow, radius: 12, y: 4)
        .animation(.spring(response: 0.3), value: safety.sosState == .idle)
    }

    private var idleState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sos")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 6) {
                Text("Emergency SOS")
                    .font(.title3.weight(.bold)).foregroundStyle(.white)
                Text("Sends your live location to everyone in your circle")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Button {
                safety.triggerManualSOS()
            } label: {
                Text("Hold to send SOS")
                    .font(.headline).foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(Capsule())
            }
        }
    }

    private func countdownState(secs: Int) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 6)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: CGFloat(secs) / 5.0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                Text("\(secs)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text("Sending SOS…")
                .font(.title3.weight(.bold)).foregroundStyle(.white)

            Button {
                safety.cancelSOS()
            } label: {
                Text("Cancel")
                    .font(.headline).foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(Capsule())
            }
        }
    }

    private var activeState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52)).foregroundStyle(.white)
            Text("SOS sent")
                .font(.title3.weight(.bold)).foregroundStyle(.white)
            Text("Your circle has been alerted")
                .font(.caption).foregroundStyle(.white.opacity(0.8))
        }
    }

    private var cancelledState: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 52)).foregroundStyle(.white.opacity(0.7))
            Text("SOS cancelled")
                .font(.title3.weight(.bold)).foregroundStyle(.white)
        }
    }

    private var cardBackground: some ShapeStyle {
        switch safety.sosState {
        case .idle:      return LinearGradient(colors: [.red, Color(red: 0.8, green: 0, blue: 0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .countdown: return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .active:    return LinearGradient(colors: [.green, Color(red: 0, green: 0.6, blue: 0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cancelled: return LinearGradient(colors: [Color(.systemGray3), Color(.systemGray4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var cardShadow: Color {
        switch safety.sosState {
        case .idle, .countdown: return .red.opacity(0.3)
        case .active:           return .green.opacity(0.3)
        case .cancelled:        return .clear
        }
    }
}

// MARK: - Privacy row

struct PrivacyRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 36)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
