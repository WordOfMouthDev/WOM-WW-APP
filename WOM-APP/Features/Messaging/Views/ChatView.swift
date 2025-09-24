
import SwiftUI
import FirebaseAuth
import PhotosUI
import UIKit

struct ChatView: View {
    @State private var chat: Chat
    @ObservedObject var messagingManager: MessagingManager
    @ObservedObject var toastManager: ToastManager

    @State private var messageText = ""
    @State private var attachmentPhotoItem: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var presentedImage: PresentedImage?
    @State private var showingChatInfo = false

    @State private var scrollProxy: ScrollViewProxy?
    @State private var isUserAtBottom = true
    @State private var isInitialLoadComplete = false
    @State private var isPaginating = false
    @State private var firstVisibleMessageId: String?
    @State private var paginationAnchorId: String?

    @FocusState private var isInputFocused: Bool

    private let timestampGroupingInterval: TimeInterval = 5 * 60
    private let calendar = Calendar.current

    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    init(chat: Chat, messagingManager: MessagingManager, toastManager: ToastManager) {
        _chat = State(initialValue: chat)
        self.messagingManager = messagingManager
        self.toastManager = toastManager
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesScrollView
            if shouldShowTypingIndicator {
                TypingIndicatorView(usernames: messagingManager.typingUsernames)
                    .transition(.opacity)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
            }
            messageInputView
        }
        .background(Color(.systemBackground))
        .navigationTitle(chatTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingChatInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showingChatInfo) {
            ChatInfoView(chat: $chat, messagingManager: messagingManager)
        }
        .sheet(item: $presentedImage) { item in
            ImageViewer(item: item)
        }
        .toast(toastManager)
        .task {
            await loadInitialMessages()
        }
        .onReceive(messagingManager.$chats) { chats in
            if let updated = chats.first(where: { $0.id == chat.id }) {
                chat = updated
            }
        }
        .onChange(of: attachmentPhotoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            pendingImageData = data
                        }
                    }
                } catch {
                    await MainActor.run {
                        toastManager.showError("Unable to load selected image. Please try again.")
                    }
                }
                await MainActor.run {
                    attachmentPhotoItem = nil
                }
            }
        }
        .onChange(of: messagingManager.isLoadingInitial) { _, isLoading in
            if !isLoading && !messagingManager.messages.isEmpty {
                isInitialLoadComplete = true
                scrollToBottom(animated: false)
            }
        }
        .overlay(alignment: .center) {
            catchUpPill
        }
        .overlay(alignment: .bottomTrailing) {
            scrollToBottomButton
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                if isInputFocused {
                    isInputFocused = false
                    //hideKeyboard()
                }
            }
        )
    }

    private var messagesScrollView: some View {
        GeometryReader { outerGeo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        topSentinel

                        if messagingManager.isLoadingOlder || isPaginating {
                            ProgressView()
                                .scaleEffect(0.75)
                                .padding(.vertical, 8)
                        }

                        ForEach(timelineItems) { entry in
                            timelineEntryView(for: entry)
                                .id(entry.id)
                        }

                        bottomSentinel
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .coordinateSpace(name: "chatScroll")
                .onPreferenceChange(TopOffsetPreferenceKey.self) { value in
                    handleTopOffset(value, proxy: proxy)
                }
                .onPreferenceChange(BottomOffsetPreferenceKey.self) { value in
                    handleBottomOffset(value, containerHeight: outerGeo.size.height)
                }
                .onPreferenceChange(MessageVisibilityPreferenceKey.self) { values in
                    updateFirstVisibleMessage(with: values)
                }
                .onChange(of: messagingManager.messages.count) { oldValue, newValue in
                    handleMessageCountChange(oldValue: oldValue, newValue: newValue, proxy: proxy)
                }
                .onAppear {
                    scrollProxy = proxy
                    if isInitialLoadComplete {
                        DispatchQueue.main.async {
                            scrollToBottom(animated: false)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var topSentinel: some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: TopOffsetPreferenceKey.self,
                        value: geo.frame(in: .named("chatScroll")).minY
                    )
                }
            )
    }

    private var bottomSentinel: some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: BottomOffsetPreferenceKey.self,
                        value: geo.frame(in: .named("chatScroll")).maxY
                    )
                }
            )
    }

    @ViewBuilder
    private var catchUpPill: some View {
        if !isUserAtBottom && messagingManager.unreadCount > 0 {
            Button {
                scrollToBottom(animated: true)
                Task { await messagingManager.markRead(chatId: chat.id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.footnote)
                    Text("Catch Up")
                        .fontWeight(.semibold)
                    Text("·")
                    Text("\(messagingManager.unreadCount) new")
                }
                .font(.footnote)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
            }
            .padding(.bottom, 120)
        }
    }

    @ViewBuilder
    private var scrollToBottomButton: some View {
        if !isUserAtBottom {
            Button {
                scrollToBottom(animated: true)
                Task { await messagingManager.markRead(chatId: chat.id) }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(16)
                    .background(
                        Circle()
                            .fill(Color.blue)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                    .overlay(alignment: .topTrailing) {
                        if messagingManager.unreadCount > 0 {
                            Text("\(min(messagingManager.unreadCount, 99))")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.red))
                                .offset(x: 8, y: -8)
                        }
                    }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 24)
        }
    }

    private var messageInputView: some View {
        VStack(spacing: 8) {
            if let data = pendingImageData,
               let image = UIImage(data: data) {
                HStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        withAnimation {
                            pendingImageData = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $attachmentPhotoItem, matching: .images) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                }
                .disabled(messagingManager.isUploadingAttachment)
                .accessibilityLabel("Add attachment")

                TextField("Message", text: $messageText, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(1...6)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)

                Button(action: sendCurrentMessage) {
                    if messagingManager.isSendingMessage || messagingManager.isUploadingAttachment {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(canSend ? .blue : .gray)
                    }
                }
                .disabled(!canSend || messagingManager.isSendingMessage || messagingManager.isUploadingAttachment)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    private var canSend: Bool {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || pendingImageData != nil
    }

    private func sendCurrentMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageData = pendingImageData
        guard !trimmed.isEmpty || imageData != nil else { return }

        if !trimmed.isEmpty {
            Task { await messagingManager.sendMessage(trimmed, to: chat.id) }
        }

        if let data = imageData {
            Task { await messagingManager.sendImageMessage(data, to: chat.id) }
        }

        messageText = ""
        pendingImageData = nil
    }

    private func loadInitialMessages() async {
        await messagingManager.loadInitialMessages(chatId: chat.id)
        await MainActor.run {
            isInitialLoadComplete = true
            scrollToBottom(animated: false)
        }
        await messagingManager.markRead(chatId: chat.id)
    }

    private func handleTopOffset(_ value: CGFloat, proxy: ScrollViewProxy) {
        guard !isPaginating,
              !messagingManager.isLoadingOlder,
              messagingManager.hasMoreOlder,
              isInitialLoadComplete else { return }

        if value > -60 {
            isPaginating = true
            paginationAnchorId = firstVisibleMessageId ?? orderedMessages.first?.id

            Task {
                await messagingManager.loadOlderMessages(chatId: chat.id)
                await MainActor.run {
                    if let anchor = paginationAnchorId {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(anchor, anchor: .top)
                        }
                    }
                    paginationAnchorId = nil
                    isPaginating = false
                }
            }
        }
    }

    private func handleBottomOffset(_ value: CGFloat, containerHeight: CGFloat) {
        let threshold: CGFloat = 80
        let atBottom = value <= containerHeight + threshold
        if atBottom != isUserAtBottom {
            isUserAtBottom = atBottom
            if atBottom {
                Task { await messagingManager.markRead(chatId: chat.id) }
            }
        }
    }

    private func updateFirstVisibleMessage(with values: [String: CGFloat]) {
        guard !values.isEmpty else { return }
        let sorted = values.sorted { $0.value < $1.value }
        if let first = sorted.first(where: { $0.value >= -1 }) {
            firstVisibleMessageId = first.key
        }
    }

    private func handleMessageCountChange(oldValue: Int, newValue: Int, proxy: ScrollViewProxy) {
        guard newValue != oldValue, newValue > 0 else { return }
        guard isInitialLoadComplete else { return }

        let messages = orderedMessages
        guard let lastMessage = messages.last else { return }

        if lastMessage.senderId == currentUserId {
            scrollToBottom(animated: true)
        } else if isUserAtBottom {
            scrollToBottom(animated: true)
            Task { await messagingManager.markRead(chatId: chat.id) }
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard let proxy = scrollProxy,
              let lastId = orderedMessages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }

    private var orderedMessages: [Message] {
        messagingManager.messages.sorted(by: messageSort)
    }

    private func messageSort(_ lhs: Message, _ rhs: Message) -> Bool {
        if lhs.timestamp == rhs.timestamp {
            return lhs.id < rhs.id
        }
        return lhs.timestamp < rhs.timestamp
    }

    private var timelineItems: [TimelineEntry] {
        var items: [TimelineEntry] = []
        var previousDay: DateComponents?
        var previousTimestamp: Date?
        var insertedUnread = false
        let unreadId = messagingManager.firstUnreadMessageId

        for message in orderedMessages {
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: message.timestamp)
            if dayComponents != previousDay {
                items.append(.day(message.timestamp))
                previousDay = dayComponents
                previousTimestamp = nil
            }

            if let lastTimestamp = previousTimestamp {
                if message.timestamp.timeIntervalSince(lastTimestamp) > timestampGroupingInterval {
                    items.append(.time(message.timestamp))
                }
            } else {
                items.append(.time(message.timestamp))
            }

            if !insertedUnread, let unreadId, unreadId == message.id {
                items.append(.unreadDivider)
                insertedUnread = true
            }

            items.append(.message(message))
            previousTimestamp = message.timestamp
        }

        return items
    }

    @ViewBuilder
    private func timelineEntryView(for entry: TimelineEntry) -> some View {
        switch entry {
        case .day(let date):
            DayDivider(date: date)
        case .time(let date):
            TimeDivider(date: date)
        case .unreadDivider:
            UnreadDividerView()
        case .message(let message):
            messageRow(for: message)
        }
    }

    @ViewBuilder
    private func messageRow(for message: Message) -> some View {
        MessageBubbleView(
            message: message,
            isCurrentUser: message.senderId == currentUserId,
            showSenderInfo: shouldShowSenderInfo(for: message),
            onDelete: message.senderId == currentUserId ? {
                Task { await messagingManager.deleteMessage(message.id, from: chat.id) }
            } : nil,
            forceShowTimestamp: false,
            onImageTap: { presentedImage = PresentedImage(url: $0) }
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: MessageVisibilityPreferenceKey.self,
                    value: [message.id: geo.frame(in: .named("chatScroll")).minY]
                )
            }
        )
    }

    private func shouldShowSenderInfo(for message: Message) -> Bool {
        guard chat.type == .group else { return false }
        guard message.senderId != currentUserId else { return false }
        guard let previous = previousMessage(before: message) else { return true }
        return previous.senderId != message.senderId
    }

    private func previousMessage(before message: Message) -> Message? {
        let messages = orderedMessages
        guard let index = messages.firstIndex(where: { $0.id == message.id }), index > 0 else { return nil }
        return messages[index - 1]
    }

    private var shouldShowTypingIndicator: Bool {
        !messagingManager.typingUsernames.isEmpty
    }

    private var chatTitle: String {
        if chat.type == .group {
            return chat.name ?? "Group Chat"
        }
        if let other = chat.getOtherParticipant(currentUserId: currentUserId) {
            return other.displayName
        }
        return "Chat"
    }
}

private enum TimelineEntry: Identifiable, Equatable {
    case day(Date)
    case time(Date)
    case unreadDivider
    case message(Message)

    var id: String {
        switch self {
        case .day(let date):
            return "day-\(date.timeIntervalSince1970)"
        case .time(let date):
            return "time-\(date.timeIntervalSince1970)"
        case .unreadDivider:
            return "unread-divider"
        case .message(let message):
            return message.id
        }
    }
}

private struct TopOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

private struct BottomOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MessageVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct DayDivider: View {
    let date: Date

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        Text(Self.formatter.string(from: date))
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
    }
}

private struct TimeDivider: View {
    let date: Date

    var body: some View {
        Text(date, style: .time)
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color(.systemGray6))
            )
            .frame(maxWidth: .infinity)
    }
}

private struct UnreadDividerView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Rectangle()
                .fill(Color.blue.opacity(0.35))
                .frame(height: 1)

            Text("New Messages")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color.blue)
                )

            Rectangle()
                .fill(Color.blue.opacity(0.35))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TypingIndicatorView: View {
    let usernames: [String]

    private var typingText: String {
        switch usernames.count {
        case 0:
            return "Typing…"
        case 1:
            return "\(usernames[0]) is typing…"
        case 2:
            return "\(usernames[0]) and \(usernames[1]) are typing…"
        default:
            return "\(usernames[0]), \(usernames[1]), and others are typing…"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
            Text(typingText)
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    let showSenderInfo: Bool
    let onDelete: (() -> Void)?
    let forceShowTimestamp: Bool
    let onImageTap: ((URL) -> Void)?

    var body: some View {
        if message.type == .system {
            systemMessageBubble
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        } else {
            ZStack(alignment: .trailing) {
                rowContent
                    .offset(x: forceShowTimestamp ? -timestampShift : 0)
                    .animation(.easeInOut(duration: 0.2), value: forceShowTimestamp)

                if forceShowTimestamp {
                    timestampLabel
                        .padding(.trailing, 16)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .contextMenu {
                if isCurrentUser, let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Message", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private var messageBubble: some View {
        Group {
            switch message.type {
            case .text:
                textMessageBubble
            case .image:
                imageMessageBubble
            case .system:
                systemMessageBubble
            }
        }
    }
    
    private var textMessageBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(isCurrentUser ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isCurrentUser ? Color.blue : Color(.systemGray5))
            )
    }
    
    private var imageMessageBubble: some View {
        let urlString = message.imageURL?.isEmpty == false ? message.imageURL : (URL(string: message.content) != nil ? message.content : nil)

        return Group {
            if let urlString,
               let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderImage
                }
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .onTapGesture {
                    onImageTap?(url)
                }
            } else {
                placeholderImage
                    .frame(width: 220, height: 220)
            }
        }
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(.systemGray6))
            .overlay(
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(.gray)
            )
    }
    
    private var systemMessageBubble: some View {
        Text(message.content)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var rowContent: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isCurrentUser {
                Spacer(minLength: 60)
                bubbleContent
            } else {
                bubbleContent
                Spacer(minLength: 60)
            }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            if showSenderInfo && !isCurrentUser {
                HStack(spacing: 6) {
                    CachedAsyncImage(url: URL(string: message.senderProfileImageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())

                    Text(message.senderName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }

            messageBubble

            if let statusText = statusLabelText {
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(statusLabelColor)
            }
        }
    }

    private var timestampLabel: some View {
        Text(message.timestamp, style: .time)
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
    }

    private var timestampShift: CGFloat { 80 }

    private var statusLabelText: String? {
        guard isCurrentUser, message.type != .system else { return nil }
        switch message.status {
        case .sending:
            return "Sending…"
        case .sent:
            return "Sent"
        case .delivered:
            return "Delivered"
        case .read:
            return "Read"
        case .failed:
            return "Failed"
        }
    }

    private var statusLabelColor: Color {
        switch message.status {
        case .failed:
            return .red
        case .sending:
            return Color.secondary.opacity(0.9)
        default:
            return .secondary
        }
    }
}

struct PresentedImage: Identifiable {
    let id = UUID()
    let url: URL
}

struct ImageViewer: View {
    let item: PresentedImage
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                CachedAsyncImage(url: item.url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                } placeholder: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        prepareShare()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $isPresentingShareSheet) {
            ActivityView(activityItems: shareItems)
        }
    }

    private func prepareShare() {
        var items: [Any] = []
        if let cached = ImageCache.shared.image(for: item.url as NSURL) {
            items = [cached]
        } else if let data = try? Data(contentsOf: item.url),
                  let image = UIImage(data: data) {
            ImageCache.shared.insert(image, for: item.url as NSURL)
            items = [image]
        } else {
            items = [item.url]
        }
        shareItems = items
        isPresentingShareSheet = true
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


struct ChatInfoView: View {
    @Binding var chat: Chat
    @ObservedObject var messagingManager: MessagingManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingLeaveAlert = false
    @State private var showingAddMembers = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var groupName: String = ""
    @State private var groupDescription: String = ""
    @State private var isSaving = false
    @ObservedObject private var friendsManager = FriendsManager()
    
    private var trimmedGroupName: String {
        groupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var trimmedDescription: String {
        groupDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var hasGroupChanges: Bool {
        let nameChanged = chat.type == .group && !trimmedGroupName.isEmpty && trimmedGroupName != (chat.name ?? "")
        let descriptionChanged = trimmedDescription != (chat.description ?? "")
        let imageChanged = selectedImageData != nil
        return nameChanged || descriptionChanged || imageChanged
    }
    
    var body: some View {
        NavigationView {
            List {
                // Chat header
                Section {
                    VStack(spacing: 16) {
                        // Chat image
                        Group {
                            if let data = selectedImageData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if let url = URL(string: chat.displayImage), !chat.displayImage.isEmpty {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    placeholderCircle
                                }
                            } else {
                                placeholderCircle
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 2)
                                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
                        )
                        
                        if chat.type == .group {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text("Change Photo")
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                            }
                            .onChange(of: selectedPhotoItem) { _, item in
                                guard let item else { return }
                                Task {
                                    if let data = try? await item.loadTransferable(type: Data.self) {
                                        await MainActor.run { self.selectedImageData = data }
                                    }
                                }
                            }
                        }
                        
                        VStack(spacing: 4) {
                            let displayTitle = chat.type == .group
                                ? (trimmedGroupName.isEmpty ? (chat.name ?? "Group Chat") : trimmedGroupName)
                                : chat.displayName
                            Text(displayTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            if chat.type == .group {
                                Text("\(chat.participants.count) participants")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                if chat.type == .group {
                    Section("Group Details") {
                        TextField("Group Name", text: $groupName)
                        TextField("Description", text: $groupDescription, axis: .vertical)
                            .lineLimit(1...3)
                    }
                }
                
                // Participants
                Section("Participants") {
                    ForEach(chat.participants) { participant in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: participant.profileImageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(participant.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    if participant.isAdmin {
                                        Text("Admin")
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text("@\(participant.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                // Actions
                Section {
                    if chat.type == .group {
                        Button(action: {
                            showingAddMembers = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Add Members")
                            }
                        }
                        
                        Button(action: {
                            showingLeaveAlert = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                Text("Leave Group")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chat Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if chat.type == .group {
                            Button("Save") {
                                Task { await saveChanges() }
                            }
                            .disabled(!hasGroupChanges || messagingManager.isLoading || isSaving)
                        }
                        Button("Done") { dismiss() }
                    }
                }
            }
            .alert("Leave Group", isPresented: $showingLeaveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    Task {
                        await messagingManager.leaveChat(chat.id)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to leave this group? You won't be able to see new messages.")
            }
            .sheet(isPresented: $showingAddMembers) {
                AddGroupMembersView(
                    existingParticipantIds: Set(chat.participants.map { $0.uid }),
                    friendsManager: friendsManager
                ) { friendsToAdd in
                    Task { await addMembers(friendsToAdd) }
                }
            }
            .onAppear {
                groupName = chat.name ?? ""
                groupDescription = chat.description ?? ""
            }
            .onChange(of: chat) { _, newValue in
                groupName = newValue.name ?? ""
                groupDescription = newValue.description ?? ""
            }
        }
    }
    
    private var placeholderCircle: some View {
        Circle()
            .fill(chat.type == .group ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: chat.type == .group ? "person.2.fill" : "person.fill")
                    .font(.title)
                    .foregroundColor(chat.type == .group ? .blue : .gray)
            )
    }
    
    private func saveChanges() async {
        guard chat.type == .group else { return }
        isSaving = true
        let nameToSend: String?
        if trimmedGroupName.isEmpty || trimmedGroupName == (chat.name ?? "") {
            nameToSend = nil
        } else {
            nameToSend = trimmedGroupName
        }
        let descriptionToSend = trimmedDescription == (chat.description ?? "") ? nil : trimmedDescription
        let imageDataToSend = selectedImageData
        if let updatedChat = await messagingManager.updateGroupChatDetails(
            chatId: chat.id,
            newName: nameToSend,
            newDescription: descriptionToSend,
            imageData: imageDataToSend
        ) {
            await MainActor.run {
                chat = updatedChat
                groupName = updatedChat.name ?? ""
                groupDescription = updatedChat.description ?? ""
                selectedImageData = nil
            }
        }
        await MainActor.run {
            isSaving = false
        }
    }
    
    private func addMembers(_ friends: [Friend]) async {
        guard !friends.isEmpty else { return }
        isSaving = true
        if let updatedChat = await messagingManager.addMembers(friends, to: chat.id) {
            await MainActor.run {
                chat = updatedChat
            }
        }
        await MainActor.run {
            isSaving = false
        }
    }
}

struct AddGroupMembersView: View {
    let existingParticipantIds: Set<String>
    @ObservedObject var friendsManager: FriendsManager
    let onAdd: ([Friend]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFriends = Set<String>()
    
    private var filteredFriends: [Friend] {
        friendsManager.friends
            .filter { !existingParticipantIds.contains($0.uid) }
            .filter { friend in
                guard !searchText.isEmpty else { return true }
                return friend.displayName.localizedCaseInsensitiveContains(searchText) ||
                       friend.username.localizedCaseInsensitiveContains(searchText)
            }
    }
    
    var body: some View {
        NavigationView {
            List {
                if filteredFriends.isEmpty {
                    Text("No additional friends available")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredFriends) { friend in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: friend.profileImageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(.headline)
                                Text("@\(friend.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedFriends.contains(friend.uid) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedFriends.contains(friend.uid) {
                                selectedFriends.remove(friend.uid)
                            } else {
                                selectedFriends.insert(friend.uid)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Add Members")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let friendsToAdd = friendsManager.friends.filter { selectedFriends.contains($0.uid) }
                        onAdd(friendsToAdd)
                        dismiss()
                    }
                    .disabled(selectedFriends.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ChatView(
            chat: Chat(
                type: .direct,
                participants: [
                    ChatParticipant(uid: "1", username: "john", displayName: "John Doe"),
                    ChatParticipant(uid: "2", username: "jane", displayName: "Jane Smith")
                ],
                createdBy: "1"
            ),
            messagingManager: MessagingManager(),
            toastManager: ToastManager()
        )
    }
}
