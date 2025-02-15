//
//  HttpNetworkingLogService.swift
//  
//
//  Created by Lazar Sidor on 18.01.2022.
//

import Foundation

/// Logs network activity (outgoing requests and incoming responses).
final class HttpNetworkAPILogger: NSObject {
    private let requestDataFormatter: ((Data) -> (Data))?
    private let responseDataFormatter: ((Data) -> (Data))?
    private let logger: HttpLoggerProtocol!
    private let loggerCategory = "HTTPNetworking"
    
    /// If true, also logs response body data.
    let isVerbose: Bool
    
    init(logger: HttpLoggerProtocol,
         verbose: Bool = false,
         requestDataFormatter: ((Data) -> (Data))? = nil,
         responseDataFormatter: ((Data) -> (Data))? = nil) {
        self.logger = logger
        self.isVerbose = verbose
        self.requestDataFormatter = requestDataFormatter
        self.responseDataFormatter = responseDataFormatter
    }
    
    func willSend(_ request: URLRequest?) {
        if let request = request {
            if isVerbose {
                logger.verbose(loggerCategory, request.debugDescription)
                logger.verbose(loggerCategory, logNetworkRequest(request))

                if let curlRequest = request.curlRequest {
                    logger.verbose(loggerCategory, curlRequest)
                }
            } else {
                logger.error(loggerCategory, request.debugDescription)
                logger.error(loggerCategory, logNetworkRequest(request))
            }
        }
    }
    
    func didReceive(_ response: HTTPURLResponse?, responseData: Data?, target: URL) {
        outputItems(logNetworkResponse(response, data: responseData, target: target))
    }
    
    func reportError(_ errorMessage: String) {
        logger.error(loggerCategory, errorMessage)
    }
    
    private func outputItems(_ items: String) {
        if isVerbose {
            logger.verbose(loggerCategory, items)
        }
    }
}

extension HttpNetworkAPILogger {
    static func JSONResponseDataFormatter(data: Data) -> Data {
        do {
            let dataAsJSON = try JSONSerialization.jsonObject(with: data, options: [])
            let prettyData =  try JSONSerialization.data(withJSONObject: dataAsJSON, options: .prettyPrinted)
            return prettyData
        } catch {
            return data //fallback to original data if it cant be serialized
        }
    }

    static func JSONRequestDataFormatter(data: Data) -> Data {
        do {
            let dataAsJSON = try JSONSerialization.jsonObject(with: data, options: [])
            let prettyData =  try JSONSerialization.data(withJSONObject: dataAsJSON, options: .prettyPrinted)
            return prettyData
        } catch {
            return data //fallback to original data if it cant be serialized
        }
    }
}

private extension HttpNetworkAPILogger {
    func format(identifier: String, message: String) -> String {
        return "\(identifier): \(message) \n"
    }
    
    func logNetworkRequest(_ request: URLRequest?) -> String {
        var output = ""
        
        if let httpMethod = request?.httpMethod {
            output += format(identifier: "HTTP Request Method", message: httpMethod)
        }
        output += format(identifier: "Request", message: request?.description ?? "(invalid request)")
        
        if let headers = request?.allHTTPHeaderFields {
            output += format(identifier: "Request Headers", message: headers.description)
        }
        if let bodyStream = request?.httpBodyStream {
            output += format(identifier: "Request Body Stream", message: bodyStream.description)
        }
        if let body = request?.httpBody, let stringData = String(data: requestDataFormatter?(body) ?? body, encoding: String.Encoding.utf8), isVerbose {
            output += stringData
            output += "\n"
        }
        return output
    }
    
    func logNetworkResponse(_ response: HTTPURLResponse?, data: Data?, target: URL) -> String {
        guard let response = response else {
            return format(identifier: "Response", message: "⚠️ Received empty network response for \(target.absoluteString).")
        }
        var output = ""
        if 200..<400 ~= (response.statusCode) {
            output += "✅"
        } else {
            output += "🛑"
        }
        output += format(identifier: "Response", message: "Status Code: \(response.statusCode)  URL:\(response.url?.absoluteString ?? "")")
        
        if let data = data, let stringData = String(data: responseDataFormatter?(data) ?? data, encoding: String.Encoding.utf8), isVerbose {
            output += stringData
            output += "\n"
        }
        return output
    }
}

private extension HttpNetworkAPILogger {
    static func reversedPrint(logger: HttpLoggerProtocol, separator: String, terminator: String, items: Any...) {
        let category: String = "HttpNetworkAPILogger"
        for item in items {
            if let string = item as? String {
                logger.verbose(category, string)
            } else {
                logger.verbose(category, String(describing: item))
            }
        }
    }
}

fileprivate extension String {
    func escapingQuotes() -> String {
        return replacingOccurrences(of: "\"", with: "\\\"")
    }
}

extension URLRequest {
    public var curlRequest: String? {
        guard
            let httpMethod = self.httpMethod,
            let urlString = self.url?.absoluteString
        else {
            return nil
        }

        // Basic curl command with HTTP method
        var components = ["curl -k -X \(httpMethod) --dump-header -"]

        // Add request headers
        if let headers = allHTTPHeaderFields {
            components += headers.map { key, value in
                let escapedKey = key.escapingQuotes()
                let escapedValue = value.escapingQuotes()
                return "-H \"\(escapedKey): \(escapedValue)\""
            }
        }

        // Add request body
        if let data = httpBody, let body = String(data: data, encoding: .utf8) {
            if body.count > 0 {
                let escapedBody = body.escapingQuotes()
                components.append("-d \"\(escapedBody)\"")
            }
        }

        // Add URL
        components.append("\"\(urlString)\"")

        return components.joined(separator: " ")
    }
}
