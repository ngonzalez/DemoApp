/*
    Copyright (c) 2026 Nicolas GONZALEZ

    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
    documentation files (the “Software”), to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
    and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLteDERS BE
    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
    IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI

/// The signed-in user's picture, round: the image at `avatarUrl` (public,
/// redirects to Azure; a new picture gets a new URL, so the URL cache is
/// safe), otherwise the user's initials, otherwise a person symbol
struct UserAvatar: View {
    let avatarUrl: String?
    let firstName: String?
    let lastName: String?
    let size: CGFloat

    /// The first letter of the first and last names, "" when there are none
    var initials: String {
        [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces).first }
            .map { String($0).uppercased() }
            .joined()
    }

    var body: some View {
        Group {
            if let avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if phase.error != nil {
                        placeholder
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
        .accessibilityLabel(Text("Picture"))
    }

    // no picture (or it can't be read): the initials on a tinted circle
    @ViewBuilder
    var placeholder: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.gradient)
            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.white)
            } else {
                Text(verbatim: initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}
