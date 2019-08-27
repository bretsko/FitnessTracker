
import Foundation

public extension TimeInterval {
    
    func getDuration(hideHours shouldHide: Bool = false) -> String {
        var s = self
        let neg = s < 0
        if neg {
            s *= -1
        }
        
        let m = floor(s / 60)
        let sec = Int(fmod(s, 60))
        
        let h = floor(m / 60)
        let min = Int(fmod(m, 60))
        let doHide = shouldHide && h == 0
        
        var res = (sec < 10 ? "0" : "") + "\(sec)"
        res = (min < 10 && !doHide ? "0" : "") + "\(min):" + res
        
        return (neg ? "-" : "") + res
    }
    
    func getUNIXDateTime() -> String {
        let date = Date(timeIntervalSince1970: self)
        
        return date.getUNIXDateTime()
    }
    
    func getFormattedDateTime() -> String {
        let date = Date(timeIntervalSince1970: self)
        
        return date.getFormattedDate() + " " + date.getFormattedTime()
    }
    
    func getFormattedDate() -> String {
        let date = Date(timeIntervalSince1970: self)
        
        return date.getFormattedDate()
    }
    
    func getFormattedTime() -> String {
        let date = Date(timeIntervalSince1970: self)
        
        return date.getFormattedTime()
    }
    
}
