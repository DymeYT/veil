// Permission-backed integrations: Contacts, Calendar/Reminders, Safari tabs, menu-bar items of the front app,
// and paste-into-app. Each asks for its permission only when you first choose it, and reads data only while
// the panel is open. The app is signed with a stable local identity so granted permissions persist.
import AppKit
import ApplicationServices
import Contacts
import EventKit

// MARK: Contacts

enum ContactSource {
    static let store = CNContactStore()
    static var status: CNAuthorizationStatus { CNContactStore.authorizationStatus(for: .contacts) }

    static func items(_ q: String) -> [Item] {
        guard q.count >= 3, q.first?.isLetter == true, !q.contains(":") else { return [] }
        switch status {
        case .authorized, .limited: break
        case .notDetermined:
            guard ["contact", "contacts", "people"].contains(q.lowercased()) else { return [] }
            return [Item(kind: .action, title: "Search Contacts", subtitle: "Allow Veil Search to show matching people", symbol: "person.crop.circle",
                         action: .run([]), score: 1800, extra: "grant:contacts")]
        default: return []
        }
        let keys: [CNKeyDescriptor] = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey,
                                       CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactIdentifierKey] as [CNKeyDescriptor]
        guard let found = try? store.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: q), keysToFetch: keys) else { return [] }
        return found.prefix(4).map { c in
            let name = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let phone = c.phoneNumbers.first?.value.stringValue ?? "", email = c.emailAddresses.first.map { $0.value as String } ?? ""
            return Item(kind: .answer, title: name.isEmpty ? c.organizationName : name,
                        subtitle: ["Contact", c.organizationName].filter { !$0.isEmpty }.joined(separator: " · "), symbol: "person.crop.circle",
                        action: .open(safeURL("addressbook://\(c.identifier)")), score: 760,
                        extra: "contact\u{1F}\(phone)\u{1F}\(email)")
        }
    }

    static func request(_ then: @escaping () -> Void) {
        store.requestAccess(for: .contacts) { _, _ in DispatchQueue.main.async(execute: then) }
    }
}

func contactActions(_ it: Item) -> [SecondaryAction] {
    let parts = it.extra.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
    guard parts.first == "contact", parts.count == 3 else { return [] }
    let phone = parts[1], email = parts[2]
    var out: [SecondaryAction] = []
    if !email.isEmpty {
        out.append(SecondaryAction(title: "Email", keys: "", symbol: "envelope") { NSWorkspace.shared.open(safeURL("mailto:\(email)")) })
        out.append(SecondaryAction(title: "Copy Email", keys: "", symbol: "doc.on.doc") { copyText(email) })
    }
    if !phone.isEmpty {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        out.append(SecondaryAction(title: "Message", keys: "", symbol: "message") { NSWorkspace.shared.open(safeURL("sms:\(digits)")) })
        out.append(SecondaryAction(title: "FaceTime", keys: "", symbol: "video") { NSWorkspace.shared.open(safeURL("facetime://\(digits)")) })
        out.append(SecondaryAction(title: "Call (FaceTime Audio)", keys: "", symbol: "phone") { NSWorkspace.shared.open(safeURL("facetime-audio://\(digits)")) })
        out.append(SecondaryAction(title: "Copy Phone Number", keys: "", symbol: "doc.on.doc") { copyText(phone) })
    }
    return out
}

// MARK: Calendar and Reminders

enum CalendarSource {
    static let store = EKEventStore()
    static var events: EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .event) }
    static var reminders: EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .reminder) }

    static func grantRow(_ what: String, _ key: String) -> Item {
        Item(kind: .action, title: "Allow \(what) access", subtitle: "Veil Search reads and creates \(what.lowercased()) items you type", symbol: "calendar.badge.exclamationmark",
             action: .run([]), score: 1800, extra: "grant:\(key)")
    }

    // "cal", "today", "events": the next 24 hours, with Join for meeting links
    static func upcoming(_ q: String) -> [Item] {
        let l = q.lowercased()
        guard ["calendar", "today", "events", "agenda", "next meeting"].contains(l) else { return [] }  // "cal" stays Calculator/Calendar
        guard events == .fullAccess else { return [grantRow("Calendar", "calendar")] }
        let now = Date(), end = now.addingTimeInterval(86400)
        let evs = store.events(matching: store.predicateForEvents(withStart: now.addingTimeInterval(-1800), end: end, calendars: nil))
            .filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }.prefix(8)
        let f = DateFormatter(); f.dateFormat = "EEE h:mm a"
        if evs.isEmpty { return [Item(kind: .answer, title: "Nothing in the next 24 hours", subtitle: "Calendar", symbol: "calendar", action: .open(URL(string: "ical://")!), score: 1900)] }
        return evs.map { e in
            let link = meetingLink(e)
            return Item(kind: .answer, title: e.title ?? "Event", subtitle: "\(f.string(from: e.startDate)) · \(e.calendar.title)\(link == nil ? "" : " · Join ↵")",
                        symbol: link == nil ? "calendar" : "video", action: .open(link ?? URL(string: "ical://")!), score: 1900)
        }
    }

    static func meetingLink(_ e: EKEvent) -> URL? {
        let text = [e.url?.absoluteString, e.location, e.notes].compactMap { $0 }.joined(separator: " ")
        guard let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        return d.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url)
            .first { u in ["zoom.us", "meet.google.com", "teams.microsoft.com", "webex.com", "facetime.apple.com"].contains { u.host?.contains($0) == true } }
    }

    // "event lunch with sam fri 1pm", "remind call mum at 6pm"
    static func create(_ q: String) -> [Item] {
        let l = q.lowercased()
        let isEvent = l.hasPrefix("event "), isReminder = l.hasPrefix("remind ") || l.hasPrefix("reminder ")
        guard isEvent || isReminder else { return [] }
        let body = String(q.drop(while: { $0 != " " }).dropFirst())
        guard !body.isEmpty else { return [] }
        if isEvent && events != .fullAccess { return [grantRow("Calendar", "calendar")] }
        if isReminder && reminders != .fullAccess { return [grantRow("Reminders", "reminders")] }
        var date: Date?, title = body
        if let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
           let m = d.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)), let r = Range(m.range, in: body) {
            date = m.date
            title = body.replacingCharacters(in: r, with: "").replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",")))
            for tail in [" at", " on", " by"] where title.lowercased().hasSuffix(tail) { title = String(title.dropLast(tail.count)) }
            if title.isEmpty { title = body }  // "event lunch friday 1pm": the detector took every word
        }
        let f = DateFormatter(); f.dateFormat = "EEE d MMM, h:mm a"
        if isEvent {
            let start = date ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date().addingTimeInterval(86400))!
            let cal = store.defaultCalendarForNewEvents?.title ?? "Calendar"
            return [Item(kind: .action, title: "New event: \(title)", subtitle: "\(f.string(from: start)) – 1 hour · \(cal)   ↵ adds", symbol: "calendar.badge.plus",
                         action: .run([]), score: 2200, extra: "event\u{1F}\(title)\u{1F}\(start.timeIntervalSince1970)")]
        }
        let due = date.map { f.string(from: $0) } ?? "No due date"
        return [Item(kind: .action, title: "New reminder: \(title)", subtitle: "\(due)   ↵ adds", symbol: "checklist",
                     action: .run([]), score: 2200, extra: "reminder\u{1F}\(title)\u{1F}\(date?.timeIntervalSince1970 ?? 0)")]
    }

    static func perform(_ extra: String) -> String {
        let p = extra.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        guard p.count == 3, let t = Double(p[2]), !p[1].isEmpty else { return "" }
        if p[0] == "event" {
            let e = EKEvent(eventStore: store)
            e.title = p[1]; e.startDate = Date(timeIntervalSince1970: t); e.endDate = e.startDate.addingTimeInterval(3600)
            e.calendar = store.defaultCalendarForNewEvents
            return (try? store.save(e, span: .thisEvent)) != nil ? "Event added" : "Couldn't add the event"
        }
        let r = EKReminder(eventStore: store)
        r.title = p[1]; r.calendar = store.defaultCalendarForNewReminders()
        if t > 0 {
            r.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date(timeIntervalSince1970: t))
            r.addAlarm(EKAlarm(absoluteDate: Date(timeIntervalSince1970: t)))
        }
        return (try? store.save(r, commit: true)) != nil ? "Reminder added" : "Couldn't add the reminder"
    }

    static func request(_ key: String, _ then: @escaping () -> Void) {
        let done: (Bool, Error?) -> Void = { _, _ in DispatchQueue.main.async(execute: then) }
        if key == "calendar" { store.requestFullAccessToEvents(completion: done) } else { store.requestFullAccessToReminders(completion: done) }
    }
}

// MARK: Safari tabs (Automation permission; read once per panel open, only after you enabled it)

enum SafariTabs {
    nonisolated(unsafe) static var tabs: [Item] = []
    static var enabled: Bool { UserDefaults.standard.bool(forKey: "safariTabs") }

    static func load() {
        guard enabled, NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first != nil else { tabs = []; return }
        let src = """
        set out to ""
        tell application "Safari"
          repeat with w from 1 to count of windows
            repeat with t from 1 to count of tabs of window w
              set out to out & w & tab & t & tab & (name of tab t of window w) & tab & (URL of tab t of window w) & linefeed
            end repeat
          end repeat
        end tell
        return out
        """
        var err: NSDictionary?
        guard let s = NSAppleScript(source: src)?.executeAndReturnError(&err).stringValue else { tabs = []; return }
        tabs = s.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count == 4 else { return nil }
            let host = URL(string: f[3])?.host ?? f[3]
            let script = "tell application \"Safari\"\nset current tab of window \(f[0]) to tab \(f[1]) of window \(f[0])\nset index of window \(f[0]) to 1\nactivate\nend tell"
            return Item(kind: .web, title: f[2].isEmpty ? host : f[2], subtitle: "Safari tab · \(host)", symbol: "safari",
                        action: .run(["/usr/bin/osascript", "-e", script]), score: 120, extra: "tab")
        }
    }

    static func offer(_ q: String) -> [Item] {
        guard !enabled, q.lowercased() == "tab" || q.lowercased() == "tabs" else { return [] }
        return [Item(kind: .action, title: "Search Safari tabs", subtitle: "Allow Veil Search to list your open Safari tabs", symbol: "safari",
                     action: .run([]), score: 1800, extra: "grant:safari")]
    }
}

// MARK: menu-bar items of the frontmost app (Accessibility), e.g. "m export"

enum MenuItems {
    nonisolated(unsafe) static var frontPID: pid_t = 0
    static var trusted: Bool { AXIsProcessTrusted() }

    static func items(_ q: String) -> [Item] {
        let l = q.lowercased()
        guard l.hasPrefix("m ") || l == "menu" || l.hasPrefix("menu ") else { return [] }
        guard trusted else {
            return [Item(kind: .action, title: "Search menu items", subtitle: "Allow Accessibility so Veil Search can read the front app's menus",
                         symbol: "menubar.rectangle", action: .run([]), score: 1800, extra: "grant:accessibility")]
        }
        let term = l.hasPrefix("m ") ? String(l.dropFirst(2)) : l.hasPrefix("menu ") ? String(l.dropFirst(5)) : ""
        guard frontPID > 0 else { return [] }
        let app = AXUIElementCreateApplication(frontPID)
        var bar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &bar) == .success, let menuBar = bar else { return [] }
        let appName = NSRunningApplication(processIdentifier: frontPID)?.localizedName ?? "App"
        var out: [Item] = []
        var budget = 400
        func walk(_ el: AXUIElement, _ path: [String], depth: Int) {
            guard depth < 5, budget > 0 else { return }
            var kids: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &kids) == .success, let children = kids as? [AXUIElement] else { return }
            for c in children {
                budget -= 1
                var t: CFTypeRef?, en: CFTypeRef?
                AXUIElementCopyAttributeValue(c, kAXTitleAttribute as CFString, &t)
                let title = (t as? String) ?? ""
                var sub: CFTypeRef?
                let hasMenu = AXUIElementCopyAttributeValue(c, kAXChildrenAttribute as CFString, &sub) == .success && ((sub as? [AXUIElement])?.isEmpty == false)
                if hasMenu { walk(c, title.isEmpty ? path : path + [title], depth: depth + 1); continue }
                guard !title.isEmpty else { continue }
                AXUIElementCopyAttributeValue(c, kAXEnabledAttribute as CFString, &en)
                guard (en as? Bool) != false else { continue }
                let full = (path + [title]).dropFirst(path.first == "Apple" ? 0 : 0).joined(separator: " › ")
                guard term.isEmpty || full.lowercased().contains(term) else { continue }
                out.append(Item(kind: .action, title: title, subtitle: "\(appName) · \(path.joined(separator: " › "))", symbol: "filemenu.and.selection",
                                action: .run([]), score: 1700, extra: "menu"))
                MenuItems.elements[out.last!.id] = c
            }
        }
        elements = [:]
        walk(menuBar as! AXUIElement, [], depth: 0)
        return Array(out.prefix(30))
    }

    nonisolated(unsafe) static var elements: [String: AXUIElement] = [:]
    static func press(_ id: String) {
        guard let el = elements[id] else { return }
        NSRunningApplication(processIdentifier: frontPID)?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { AXUIElementPerformAction(el, kAXPressAction as CFString) }
    }

    static func requestTrust() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}

// MARK: paste into the frontmost app (⌥↵): pasteboard, then ⌘V into the app that was in front

func pasteIntoFrontApp(_ text: String, secret: Bool, completion: @escaping (Bool) -> Void = { _ in }) -> Bool {
    guard AXIsProcessTrusted() else { MenuItems.requestTrust(); return false }
    copyText(text, secret: secret)
    let targetPID = MenuItems.frontPID
    let pasteboardCount = NSPasteboard.general.changeCount
    guard let target = NSRunningApplication(processIdentifier: targetPID), !target.isTerminated, target.activate() else { return false }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
        // Never type into a different app, or paste unrelated text copied during the activation delay.
        guard !target.isTerminated, NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID,
              NSPasteboard.general.changeCount == pasteboardCount else { completion(false); return }
        let src = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: down)
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }
        completion(true)
    }
    return true
}
