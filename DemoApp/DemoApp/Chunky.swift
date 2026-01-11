//
//  Chunky.swift
//  DemoApp
//

import Foundation

public let CHUNK_DEFAULT_BUFFER_SIZE:Int = 1024

public enum FileChunkerError:Error
{
    case outputDirectoryInvalid
}

public class FileChunker
{
    let input:URL
    let outputDirectory:URL
    let chunkSize:Int
    let bufferSize:Int

    init( input:URL, outputDirectory:URL, chunkSize:Int, bufferSize:Int = CHUNK_DEFAULT_BUFFER_SIZE )
    {
        self.input = input
        self.outputDirectory = outputDirectory
        self.chunkSize = chunkSize
        self.bufferSize = bufferSize
    }

    func chunk( )throws->[URL]
    {
        let fileManager:FileManager = .default

        var isDirectory:ObjCBool = false
        if !fileManager.fileExists( atPath:outputDirectory.path, isDirectory:&isDirectory )
        {
            try fileManager.createDirectory( at:outputDirectory, withIntermediateDirectories:true, attributes:nil )
        }
        else
        {
            guard isDirectory.boolValue else
            {
                throw FileChunkerError.outputDirectoryInvalid
            }
        }

        var urls:[URL] = [ ]
        let reader:FileHandle = try .init( forReadingFrom:input )
        var writer:FileHandle?

        var buffer:Data?
        var chunk:Int = 0
        var i = 0
        repeat
        {
            if chunk >= chunkSize
            {
                try writer?.close( )
                writer = nil
                chunk = 0
            }

            let chunkRemaining:Int = chunkSize - chunk
            buffer = try reader.read( upToCount:min( bufferSize, chunkRemaining ) )

            if let buffer = buffer
            {
                if writer == nil
                {
                    let outputURL = outputDirectory.appendingPathComponent( "\(i)-file" ).appendingPathExtension( "block" )
                    fileManager.createFile( atPath:outputURL.path, contents:nil, attributes:nil )
                    writer = try .init( forWritingTo:outputURL )
                    urls.append( outputURL )
                    i += 1
                }
                
                writer?.write( buffer )
                chunk = chunk + buffer.count
            }
        }
        while buffer != nil

        try reader.close( )
        return urls
    }
    
}

extension URL
{
    public func chunk( to outputDirectory:URL, chunkSize:Int, bufferSize:Int = CHUNK_DEFAULT_BUFFER_SIZE )throws->[URL]
    {
        let chunker:FileChunker = .init(input:self, outputDirectory:outputDirectory, chunkSize:chunkSize, bufferSize:bufferSize )
        return try chunker.chunk( )
    }
}
