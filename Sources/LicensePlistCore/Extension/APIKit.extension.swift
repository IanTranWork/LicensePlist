import Foundation
import APIKit

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
        var request = request
        request.setValue(task.originalRequest?.value(forHTTPHeaderField: "Authorization"), forHTTPHeaderField: "Authorization")
        return request
    }
}
