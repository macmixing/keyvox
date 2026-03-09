import UIKit

final class KeyboardInputHostView: UIInputView {
    let rootView = KeyboardRootView()
    let popupOverlayView = UIView()

    override init(frame: CGRect, inputViewStyle: UIInputView.Style) {
        super.init(frame: frame, inputViewStyle: inputViewStyle)
        allowsSelfSizing = false
        backgroundColor = .clear
        clipsToBounds = true

        rootView.translatesAutoresizingMaskIntoConstraints = false
        popupOverlayView.translatesAutoresizingMaskIntoConstraints = false
        popupOverlayView.backgroundColor = .clear
        popupOverlayView.isUserInteractionEnabled = false
        popupOverlayView.clipsToBounds = false

        addSubview(rootView)
        addSubview(popupOverlayView)

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootView.topAnchor.constraint(equalTo: topAnchor),
            rootView.bottomAnchor.constraint(equalTo: bottomAnchor),

            popupOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            popupOverlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            popupOverlayView.topAnchor.constraint(equalTo: topAnchor),
            popupOverlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
