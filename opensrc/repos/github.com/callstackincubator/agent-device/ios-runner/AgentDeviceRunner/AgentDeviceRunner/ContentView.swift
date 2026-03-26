//
//  ContentView.swift
//  AgentDeviceRunner
//
//  Created by Michał Pierzchała on 30/01/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Spacer(minLength: 16)
        VStack {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Agent Device Runner")
                .padding(.top, 16)
        }
        Spacer(minLength: 16)
        Image("PoweredBy")
            .resizable()
            .scaledToFit()
            .frame(width: 180, height: 44)
            .opacity(0.8)
        .padding()
    }
}

#Preview {
    ContentView()
}
