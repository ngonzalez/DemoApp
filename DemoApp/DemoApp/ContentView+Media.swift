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
import AVKit
import Gzip
import OSLog

// Video and audio: the backend's streams and the player
extension ContentView {
    func getVideoStream(videoFile: VideoFile) {
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let url = URL(string: "\(videoFilesServiceURL)/\(videoFile.id).json")!
        let request = newGetRequest(url: url)
        let task = delegateSession.dataTask(with: request) { data, response, error in
            do {
                if (data != nil) {
                    let dataUnwrapped = data!
                    let response = try JSONDecoder().decode(Stream.self, from: dataUnwrapped)

                    DispatchQueue.main.async {
                        if response.m3u8Exists == true {
                            if !self.videoStreams.map({ $0.id }).contains(videoFile.id) {
                                self.videoStreams.append(response)
                            }
                        }
                    }
                }
            } catch let error {
                logger.error("[getVideoStream] Request: \(error)")
            }
        }

        task.resume()
    }

    func getAudioStream(audioFile: AudioFile) {
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let url = URL(string: "\(audioFilesServiceURL)/\(audioFile.id).json")!
        let request = newGetRequest(url: url)
        let task = delegateSession.dataTask(with: request) { data, response, error in
            do {
                if (data != nil) {
                    let dataUnwrapped = data!
                    let response = try JSONDecoder().decode(Stream.self, from: dataUnwrapped)

                    DispatchQueue.main.async {
                        if response.m3u8Exists == true {
                            if !self.audioStreams.map({ $0.id }).contains(audioFile.id) {
                                self.audioStreams.append(response)
                            }
                        }
                    }
                }
            } catch let error {
                logger.error("[getAudioStream] Request: \(error)")
            }
        }

        task.resume()
    }

    /* Media Player*/
    func initMediaPlayer(url: URL) {
        self.player = AVPlayer(url: url)
    }

    func pauseMediaPlayer() {
        self.player.pause()
    }

    func displayVideo(videoFile: VideoFile) {
        if self.videoStreams.map({ $0.id }).contains(videoFile.id) {
            let url = URL(string: "\(playlistsServiceURL)/video-\(videoFile.id).m3u8")!
            initMediaPlayer(url: url)
        }
    }

    func displayAudio(audioFile: AudioFile) {
        if self.audioStreams.map({ $0.id }).contains(audioFile.id) {
            let url = URL(string: "\(playlistsServiceURL)/audio-\(audioFile.id).m3u8")!
            initMediaPlayer(url: url)
        }
    }
}
