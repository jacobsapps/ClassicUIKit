import UIKit

final class HeroTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {

    weak var originView: UIView?

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        HeroAnimator(isPresenting: true, originView: originView)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        HeroAnimator(isPresenting: false, originView: originView)
    }
}

private final class HeroAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    private let duration: TimeInterval = 0.4
    private let isPresenting: Bool
    private weak var originView: UIView?

    init(isPresenting: Bool, originView: UIView?) {
        self.isPresenting = isPresenting
        self.originView = originView
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        isPresenting ? animatePresentation(using: transitionContext) : animateDismissal(using: transitionContext)
    }

    private func animatePresentation(using context: UIViewControllerContextTransitioning) {
        guard let toView = context.view(forKey: .to) else {
            context.completeTransition(false)
            return
        }

        let container = context.containerView
        let finalFrame = context.finalFrame(for: context.viewController(forKey: .to) ?? UIViewController())
        toView.frame = finalFrame
        toView.alpha = 0
        container.addSubview(toView)

        let snapshot = originSnapshot(in: container, fallback: toView)
        container.addSubview(snapshot)
        originView?.isHidden = true

        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.88, initialSpringVelocity: 0.6, options: [.curveEaseInOut]) {
            snapshot.frame = finalFrame
            toView.alpha = 1
        } completion: { finished in
            self.originView?.isHidden = false
            snapshot.removeFromSuperview()
            context.completeTransition(finished)
        }
    }

    private func animateDismissal(using context: UIViewControllerContextTransitioning) {
        guard let fromView = context.view(forKey: .from) else {
            context.completeTransition(false)
            return
        }

        let container = context.containerView
        let originFrame = originView?.convert(originView?.bounds ?? .zero, to: container) ?? CGRect(x: container.bounds.midX - 50, y: container.bounds.midY - 50, width: 100, height: 100)

        let snapshot = fromView.snapshotView(afterScreenUpdates: false) ?? UIView(frame: fromView.frame)
        snapshot.frame = fromView.frame
        container.addSubview(snapshot)
        fromView.removeFromSuperview()

        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut]) {
            snapshot.frame = originFrame
            snapshot.alpha = 0.1
        } completion: { finished in
            snapshot.removeFromSuperview()
            context.completeTransition(finished)
        }
    }

    private func originSnapshot(in container: UIView, fallback view: UIView) -> UIView {
        if let originView,
           let originSnapshot = originView.snapshotView(afterScreenUpdates: true) {
            let frame = originView.convert(originView.bounds, to: container)
            originSnapshot.frame = frame
            return originSnapshot
        }
        let fallbackSnapshot = view.snapshotView(afterScreenUpdates: true) ?? view
        fallbackSnapshot.frame = view.frame
        return fallbackSnapshot
    }
}
