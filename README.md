# Helios

**Multimodal AI assistant for datacenter engineers**, powered by Gemini 2.5 Flash and Meta Ray-Ban smart glasses.

Helios sees what engineers see, and knows even more -- grounded in your infrastructure APIs with zero hallucination.

## Visual Reasoning
Real-time computer vision through Meta Ray-Ban smart glasses. Identifies servers, reads LEDs, recognizes cable types, and inspects rack health at 1fps via Gemini multimodal.

## Voice Interface
Techs have their hands full, and Helios doesn't add anything more. Pure voice interaction through the glasses -- no phone, no screen, no extra hardware. Portable intelligence.

## Context Layer
Understands and interfaces with your existing datacenter management APIs: NetBox for inventory and topology, Redfish for real-time server health. State engine for continuous understanding with urgency prediction.

## Architecture

```
Glasses Camera → iOS App → Gemini 2.5 WebSocket → Voice + Alerts
                    ↕                    ↕
              Meta DAT SDK        NetBox + Redfish APIs
```

## Tech Stack

- **iOS**: Swift, SwiftUI, AVAudioEngine, Meta Wearables DAT SDK
- **AI**: Gemini 2.5 Flash native audio (WebSocket), structured JSON state output
- **Infrastructure**: NetBox API, Redfish BMC, mock data generators
- **Streaming**: WebRTC (one-way glasses → browser), Node.js signaling server

## Getting Started

1. Clone the repo
2. Copy `Secrets.swift.example` to `Secrets.swift` and add your Gemini API key
3. Open `CameraAccess.xcodeproj` in Xcode
4. Build and run on a physical iOS device
5. Pair your Meta Ray-Ban smart glasses

## Domains

- **Data Center**: Infrastructure monitoring with NetBox + Redfish integration
- **Cooking**: Real-time sous-chef guidance with visual state tracking
