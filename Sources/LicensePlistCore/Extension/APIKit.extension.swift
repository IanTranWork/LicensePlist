import Foundation
import APIKit
import LoggerAPI

extension Session: LicensePlistCompatible {}

extension LicensePlistExtension where Base: Session {
    func sendSync<T: Request>(_ request: T) -> Result<T.Response, SessionTaskError> {
        var result: Result<T.Response, SessionTaskError>!
        let semaphore = DispatchSemaphore(value: 0)
        self.base.send(request, callbackQueue: .sessionQueue) { _result in
            result = _result
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
    func send<T: Request>(_ request: T) -> ResultOperation<T.Response, SessionTaskError> {
        return ResultOperation<T.Response, SessionTaskError> { _ in
            return self.sendSync(request)
        }
    }

    static var shared: Session {
        Session(adapter: GitHubURLSessionAdapter(configuration: .default))
    }
}

final class GitHubURLSessionAdapter: URLSessionAdapter {
    // This method is to assist with persistence of an authorization token incase of a redirect.
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
        guard checkRedirectURL(task.originalRequest, redirected: request) else { return request }
        var request = request
        request.setValue(task.originalRequest?.value(forHTTPHeaderField: "Authorization"), forHTTPHeaderField: "Authorization")
        if request.value(forHTTPHeaderField: "Authorization")?.isEmpty == false {
            Log.info("Authorization was forwarded successfully")
        }
        else {
            Log.warning("Authorization was not forwarded")
        }
        return request
    }

    private func checkRedirectURL(_ original: URLRequest?, redirected: URLRequest) -> Bool {
        // Check the hosts are the same in case it has been redirected elsewhere
        guard let originalHost = original?.url?.host, originalHost == redirected.url?.host else { return false }
        // Check for whitelisted hosts
        var whiteList: Set<String> = []
        whiteList.insert("api.github.com")
        return whiteList.contains(redirected.url?.host ?? "")
    }
}
