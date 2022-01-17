//
//  File.swift
//  
//
//  Created by Lazar Sidor on 07.01.2022.
//

import Foundation

public protocol HttpClientLoggingInterface: AnyObject {
    func logRequest()
    func logError(_ error: Error)
}

public protocol HttpClientInterface: AnyObject {
    func defaultRequestHTTPHeaders() -> [String: String]
    func processResponseData(_ data: Data) -> Any?
    func processResponseErrors(_ data: Data) -> [NSError]?
}

open class DefaultHttpClientConfiguration: HttpClientInterface {
    public func defaultRequestHTTPHeaders() -> [String : String] {
        return [:]
    }
    
    public func processResponseData(_ data: Data) -> Any? {
        return nil
    }
    
    public func processResponseErrors(_ data: Data) -> [NSError]? {
        return nil
    }
}

open class HttpClientConfiguration: DefaultHttpClientConfiguration {
    public override init() {
        super.init()
    }
}
