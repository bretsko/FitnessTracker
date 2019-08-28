

import Foundation

extension Date {
    
    func getUNIXDateTime() -> String {
        return Date.unixDateTimeF.string(from: self)
    }
    
    func getFormattedDateTime() -> String {
        return getFormattedDate() + " " + getFormattedTime()
    }
    
    func getFormattedDate() -> String {
        return Date.localDateF.string(from: self)
    }
    
    func getFormattedTime() -> String {
        return Date.localTimeF.string(from: self)
    }
    
}

private extension Date {
    
    static let unixDateTimeF: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        return formatter
    }()
    
    static let localDateF: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter
    }()
    
    static let localTimeF: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        return formatter
    }()
}
