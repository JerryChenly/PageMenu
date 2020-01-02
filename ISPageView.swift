//
//  ISPageView.swift
//  PageMenu
//
//  Created by jerrychen on 2019/10/11.
//  Copyright © 2019 jerrychen. All rights reserved.
//
//  以UIScrollView为载体实现PageView，用作多ViewController切换管理
//

import UIKit

open class ISPageView: UIView {
    
    // MARK: public properties
    /// 数据源
    public weak var dataSource: ISPageViewDataSource?
    
    /// 事件代理
    public weak var delegate: ISPageViewDelegate?
    
    /// 当前视图依附的ViewController，由调用方设置，不能为nil
    public weak var rootViewController: UIViewController?

    /// PageView滚动方向
    @objc public enum ISPageViewScrollDirection: UInt8 {
        case forward
        case backward
    }
    
    // MARK: private properties
    /// 子ViewController容器
    private lazy var contentScrollView: UIScrollView = {
        let view = UIScrollView()
        view.delegate = self
        view.bounces = false
        view.scrollsToTop = false
        view.isPagingEnabled = true
        view.alwaysBounceHorizontal = true
        view.showsHorizontalScrollIndicator = false
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        return view
    }()
    
    /// 当前显示viewController的前一个
    private var previousViewController: UIViewController? {
        didSet {
            //add时机提前，解决webview预加载出现内容空白问题
            if let `previousViewController` = previousViewController {
                add(viewController: previousViewController)
            }
        }
    }
    
    /// 当前显示viewController的后一个
    private var nextViewController: UIViewController? {
        didSet {
            //add时机提前，解决webview预加载出现内容空白问题
            if let nextViewController = nextViewController {
                add(viewController: nextViewController)
            }
        }
    }
    
    /// 当前显示的viewController
    private var currentViewController: UIViewController?
    
    /// 滚动方向
    private var scrollDirection: ISPageViewScrollDirection?
    
    /// 记录是否正在滚动
    private var isScrolling = false
    
    /// 标记初始化视图时的滚动，不代理到上层
    private var isFakeScrolling = false
    
    /// 标记viewController切换是否存在动画
    private var isTransitionAnimated = false
    
    // MARK: init
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubview(contentScrollView)
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(contentScrollView)
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        if !isScrolling && bounds.size.width > 0 {
            isFakeScrolling = true
            contentScrollView.frame = bounds
            contentScrollView.contentSize = CGSize(width: bounds.width * 3, height: bounds.height)
            isFakeScrolling = false
            layoutChildViews()
        }
    }
}

// MARK: public methods
extension ISPageView {
    
    /// 指定当前视图
    /// - Parameter viewController: 当前指定显示的viewController
    /// - Parameter direction: 视图滚动方向
    /// - Parameter animated: 是否需要切换动画
    @objc public func select(viewController: UIViewController, direction: ISPageViewScrollDirection, animated: Bool) {
        assert(rootViewController != nil, "rootViewController不能为nil")
        assert(!rootViewController!.shouldAutomaticallyForwardAppearanceMethods, "\(rootViewController!)的属性shouldAutomaticallyForwardAppearanceMethods必须为false")
        //
        if bounds.size.width > 0 {
            if direction == .forward {
                nextViewController = viewController
                layoutChildViews()
                scrollForward(animated: animated)
            } else {
                //backward
                previousViewController = viewController
                layoutChildViews()
                scrollBackward(animated: animated)
            }
        } else {
            currentViewController = viewController
            layoutChildViews()
        }
    }
    
    /// 向前滚动
    /// - Parameter animated: 是否需要动画
    @objc public func scrollForward(animated: Bool) {
        guard nextViewController != nil else { return }
        isTransitionAnimated = animated
        contentScrollView.setContentOffset(CGPoint(x: bounds.width * 2, y: 0), animated: (isScrolling ? false : animated))
    }
    
    /// 向后滚动
    /// - Parameter animated: 是否需要动画
    @objc public func scrollBackward(animated: Bool) {
        guard previousViewController != nil else { return }
        isTransitionAnimated = animated
        contentScrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: (isScrolling ? false : animated))
    }
    
    /// 获取当前正在显示的ViewController
    @objc public func currentDisplayingController() -> UIViewController? {
        return currentViewController
    }
}

// MARK: private methods
extension ISPageView {
    
    /// 子视图布局
    private func layoutChildViews() {
        let leftInset = previousViewController == nil ? -bounds.width : 0
        let rightInset = nextViewController == nil ? -bounds.width : 0
        // 这里改变contentOffset造成的滚动不对外代理
        isFakeScrolling = true
        contentScrollView.contentOffset = CGPoint(x: bounds.width, y: 0)
        contentScrollView.contentInset = UIEdgeInsets(top: 0, left: leftInset, bottom: 0, right: rightInset)
        isFakeScrolling = false
        //
        previousViewController?.view.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        currentViewController?.view.frame = CGRect(x: bounds.width, y: 0, width: bounds.width, height: bounds.height)
        nextViewController?.view.frame = CGRect(x: bounds.width * 2, y: 0, width: bounds.width, height: bounds.height)
    }
    
    /// 处理滚动事件完结后的一些事物
    /// - Parameter viewController: 目的视图
    private func handleScroll(to viewController: UIViewController) {
        if viewController == nextViewController {
            // 前向滚动
            remove(viewController: previousViewController)
            previousViewController = currentViewController
            currentViewController = viewController
            previousViewController?.endAppearanceTransition()
            currentViewController!.endAppearanceTransition()
            nextViewController = dataSource?.pageView(self, next: viewController)
            delegate?.pageView?(self, didScrollFrom: previousViewController, to: viewController, success:true)
            
        } else if viewController == previousViewController {
            // 后向滚动
            remove(viewController: nextViewController)
            nextViewController = currentViewController
            currentViewController = viewController
            nextViewController?.endAppearanceTransition()
            currentViewController!.endAppearanceTransition()
            previousViewController = dataSource?.pageView(self, previous: viewController)
            delegate?.pageView?(self, didScrollFrom: nextViewController, to: viewController, success:true)
            
        } else if viewController == currentViewController {
            //滚动之后又回到原视图
            var destViewController: UIViewController?
            currentViewController?.beginAppearanceTransition(true, animated: isTransitionAnimated)
            //
            if scrollDirection == .forward {
                destViewController = nextViewController
                nextViewController?.beginAppearanceTransition(false, animated: isTransitionAnimated)
                remove(viewController: nextViewController)
                nextViewController?.endAppearanceTransition()
                nextViewController = dataSource?.pageView(self, next: viewController)
                
            } else if scrollDirection == .backward {
                destViewController = previousViewController
                previousViewController?.beginAppearanceTransition(false, animated: isTransitionAnimated)
                remove(viewController: previousViewController)
                previousViewController?.endAppearanceTransition()
                previousViewController = dataSource?.pageView(self, previous: viewController)
            }
            //
            currentViewController?.endAppearanceTransition()
            if let `destViewController` = destViewController {
                delegate?.pageView?(self, didScrollFrom: currentViewController!, to: destViewController, success:false)
            }
        }
        isScrolling = false
        scrollDirection = nil
    }
    
    /// 移除子视图
    /// - Parameter viewController: UIViewController
    private func remove(viewController: UIViewController?) {
        guard viewController?.parent != nil else { return }
        viewController?.view.removeFromSuperview()
        viewController?.removeFromParent()
    }
    
    /// 添加子视图
    /// - Parameter viewController: UIViewController
    private func add(viewController: UIViewController) {
        guard viewController.parent == nil else { return }
        contentScrollView.addSubview(viewController.view)
        rootViewController?.addChild(viewController)
        viewController.didMove(toParent: rootViewController)
    }
    
    /// 处理视图即将切换时的状态
    /// - Parameter from: 源视图
    /// - Parameter to: 目的视图
    private func pageWillScroll(from: UIViewController?, to: UIViewController) {
        if let `from` = from {
            delegate?.pageView?(self, willScrollFrom: from, to: to)
        }
        from?.beginAppearanceTransition(false, animated: isTransitionAnimated)
        to.beginAppearanceTransition(true, animated: isTransitionAnimated)
    }
    
    /// 处理视图已切换时的状态
    /// - Parameter to: 目的视图
    private func pageDidScroll(to: UIViewController) {
        handleScroll(to: to)
        layoutChildViews()
        adjustNeighbours()
    }
    
    /// 校准previous和next
    private func adjustNeighbours() {
        guard let `currentViewController` = currentViewController else { return }
        var needLayoutChilds = false
        //previous
        let previous = dataSource?.pageView(self, previous: currentViewController)
        if previous != previousViewController {
            if (previousViewController != currentViewController){
                remove(viewController: previousViewController)
            }
            previousViewController = previous
            needLayoutChilds = true
        }
        if (previous == nil && bounds.width > 0){
            _ = contentScrollView.subviews.filter {
                return $0.frame.origin.x == 0 && $0.frame.size.height == bounds.height
            }.map{
                removeFromContentScrollView($0)
            }
        }
        //next
        let next = dataSource?.pageView(self, next: currentViewController)
        if next != nextViewController {
            if nextViewController != currentViewController {
                remove(viewController: nextViewController)
            }
            nextViewController = next
            needLayoutChilds = true
        }
        if (next == nil && bounds.width > 0){
            _ = contentScrollView.subviews.filter {
                return $0.frame.origin.x == 2*bounds.width && $0.frame.size.height == bounds.height
            }.map{
                removeFromContentScrollView($0)
            }
        }
        //
        if needLayoutChilds {
            layoutChildViews()
        }
    }
    
    /// 删除contentScrollView中的ViewController子视图
    /// - Parameter view: UIView
    private func removeFromContentScrollView(_ view: UIView) {
        var responder: UIResponder = view
        while let nextResponder = responder.next {
            if nextResponder.isKind(of: UIViewController.classForCoder()) {
                remove(viewController: nextResponder as? UIViewController)
                break;
            } else {
                responder = nextResponder
            }
        }
    }
}

// MARK: UIScrollViewDelegate
extension ISPageView: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isFakeScrolling else { return }
        //视图切换进度
        //避免出现0值计算，默认取一个很小的浮点数作为scrollView的宽度
        let scrollViewWidth = max(scrollView.bounds.width, 1e-10)
        let scrollProgress = (scrollView.contentOffset.x - scrollViewWidth) / scrollViewWidth
        if scrollProgress > 0 {//forward
            guard let `nextViewController` = nextViewController else { return }
            if !isScrolling {
                pageWillScroll(from: currentViewController, to: nextViewController)
            } else if scrollDirection == .backward {
                pageDidScroll(to: currentViewController!)
                pageWillScroll(from: currentViewController, to: nextViewController)
            }
            //
            isScrolling = true
            scrollDirection = .forward
            if let `currentViewController` = currentViewController {
                delegate?.pageView?(self, scrollingFrom: currentViewController, to: nextViewController, progress: scrollProgress)
            }
            
        } else if scrollProgress < 0 {//backward
            guard let `previousViewController` = previousViewController else { return }
            if !isScrolling {
                pageWillScroll(from: currentViewController, to: previousViewController)
            } else if scrollDirection == .forward {
                pageDidScroll(to: currentViewController!)
                pageWillScroll(from: currentViewController, to: previousViewController)
            }
            //
            isScrolling = true
            scrollDirection = .backward
            if let `currentViewController` = currentViewController {
                delegate?.pageView?(self, scrollingFrom: currentViewController, to: previousViewController, progress: scrollProgress)
            }
        }
        //
        if scrollProgress == 0 && currentViewController != nil {
            pageDidScroll(to: currentViewController!)
        } else if scrollProgress >= 1 && nextViewController != nil {
            pageDidScroll(to: nextViewController!)
        } else if scrollProgress <= -1 && previousViewController != nil {
            pageDidScroll(to: previousViewController!)
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isTransitionAnimated = true
    }
}

// MARK: ISPageViewDataSource declaration
@objc public protocol ISPageViewDataSource {
    
    /// 返回指定viewController的前一个viewController
    /// - Parameter view: ISPageView
    /// - Parameter viewController: UIViewController
    func pageView(_ view: ISPageView, previous viewController: UIViewController) -> UIViewController?
    
    /// 返回指定viewController的后一个viewController
    /// - Parameter view: ISPageView
    /// - Parameter viewController: UIViewController
    func pageView(_ view: ISPageView, next viewController: UIViewController) -> UIViewController?
    
}

// MARK: ISPageViewDelegate declaration
@objc public protocol ISPageViewDelegate {
    
    /// pageView中的子视图即将从src滚动到dest，滚动事件还未发生
    /// - Parameter view: ISPageView
    /// - Parameter src: 源viewController
    /// - Parameter dest: 目的viewController
    @objc optional func pageView(_ view: ISPageView, willScrollFrom src: UIViewController, to dest: UIViewController)
    
    /// pageView中的子视图正在从src滚动到dest，滚动事件正在发生
    /// - Parameter view: ISPageView
    /// - Parameter src: 源viewController
    /// - Parameter dest: 目的viewController
    /// - Parameter progress: 滚动进度
    @objc optional func pageView(_ view: ISPageView, scrollingFrom src:UIViewController, to dest:UIViewController, progress: CGFloat)
    
    /// pageView中的子视图已经从src滚动到dest，滚动事件已经完成
    /// - Parameter view: ISPageViewController
    /// - Parameter src: 源viewController
    /// - Parameter dest: 目的viewController
    /// - Parameter success: 视图切换是否成功
    @objc optional func pageView(_ view: ISPageView, didScrollFrom src:UIViewController?, to dest: UIViewController, success: Bool)

}

