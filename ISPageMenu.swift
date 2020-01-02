//
//  ISPageMenu.swift
//  PageMenu
//
//  Created by jerrychen on 2019/10/11.
//  Copyright © 2019 jerrychen. All rights reserved.
//
//  结合ISPageView和ISMenuTabView实现多ViewController视图切换，顶部带tab标签
//

import UIKit
import SnapKit

open class ISPageMenu: UIView {
    
    // MARK: public properties
    /// 当前视图依附的ViewController，由调用方设置，不能为nil
    @objc public weak var rootViewController: UIViewController? {
        didSet {
            pageView.rootViewController = rootViewController
        }
    }
    
    /// 顶部TabView的高度
    @objc public var tabHeight: CGFloat = 40 {
        didSet {
            if oldValue != tabHeight {
                menuTabView.snp.updateConstraints { make in
                    make.height.equalTo(tabHeight)
                }
                layoutIfNeeded()
            }
        }
    }
    
    /// 标签填充视图窗口；设置为true，当tab内容+预设最小间距不足以撑满视图窗口时，会自动扩大间距以撑满。
    /// isSegmentTabStyle = true时，忽略该设置
    @objc public var isTabFillWindow: Bool = true {
        didSet {
            menuTabView.isFillWindow = isTabFillWindow
        }
    }
    
    /// 顶部tab标签呈现segment样式
    @objc public var isSegmentTabStyle: Bool = false {
        didSet {
            menuTabView.isSegmentStyle = isSegmentTabStyle
        }
    }
    
    /// tab外边距
    @objc public var tabReservedInsets: UIEdgeInsets = .zero {
        didSet {
            menuTabView.reservedInsets = tabReservedInsets
        }
    }
    
    /// 当前选中的索引，若当前没有选中的VC则返回-1
    @objc public var currentSelectionIndex: NSInteger {
        if let currentVc = pageView.currentDisplayingController(),
            let `controllers` = controllers,
            let index = controllers.firstIndex(of: currentVc) {
            return index
        } else {
            return -1
        }
    }
    
    @objc public weak var dataSource: ISPageMenuDataSource?
    @objc public weak var delegate: ISPageMenuDelegate?
    
    // MARK: private properties
    /// ViewController管理视图
    private lazy var pageView: ISPageView = {
        let view = ISPageView(frame: bounds)
        view.backgroundColor = .clear
        view.delegate = self
        view.dataSource = self
        return view
    }()
    
    /// tab管理视图
    private lazy var menuTabView: ISMenuTabView = {
        let view = ISMenuTabView()
        view.dataSource = self
        view.delegate = self
        return view
    }()
    
    /// 内容ViewControllers
    private var controllers: [UIViewController]?
    
    // MARK: init
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(menuTabView)
        addSubview(pageView)
        setupConstraints()
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        select(index: currentSelectionIndex, direction: .forward, animated: false)
    }
}

// MARK: public methods
extension ISPageMenu {
    
    /// 加载数据，titles与controllers数量需要匹配
    /// - Parameter titles: 标题
    /// - Parameter controllers: [UIViewController]
    @objc public func reload(titles: [String], controllers:[UIViewController]) {
        guard titles.count > 0 && titles.count == controllers.count else { return }
        menuTabView.tabTitles = titles
        self.controllers = controllers
        select(index: currentSelectionIndex, direction: .forward, animated: false)
    }
    
    /// 当tab样式源有变更时调用重刷
    @objc public func refreshTabDisplay() {
        menuTabView.refreshDisplay()
    }
    
    /// 选择指定索引的tab，调用之前需要确保曾经调用过load方法
    /// - Parameter index: tab索引
    /// - Parameter direction: 视图滚动方向
    /// - Parameter animated: 是否需要动画
    @objc public func select(index: NSInteger, direction: ISPageView.ISPageViewScrollDirection, animated: Bool) {
        guard let `controllers` = controllers else { return }
        guard controllers.count > index && index >= 0 else { return }
        menuTabView.select(index: index, animated: animated)
        pageView.select(viewController: controllers[index], direction: direction, animated: animated)
    }
    
    /// 根据索引获取ViewController
    /// - Parameter index: 索引值
    @objc public func controller(at index: NSInteger) -> UIViewController? {
        guard let `controllers` = controllers else { return nil }
        guard index >= 0 && index < controllers.count else { return nil }
        return controllers[index]
    }
    
    /// 获取所有视图ViewController
    @objc public func viewControllers() -> [UIViewController]? {
        return controllers
    }
}

// MARK: private methods
extension ISPageMenu {
    private func setupConstraints() {
        menuTabView.snp.makeConstraints { make in
            make.left.top.right.equalTo(self)
            make.height.equalTo(tabHeight)
        }
        pageView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(self)
            make.top.equalTo(menuTabView.snp.bottom)
        }
    }
}

// MARK: ISPageViewDataSource
extension ISPageMenu: ISPageViewDataSource {
    public func pageView(_ view: ISPageView, previous viewController: UIViewController) -> UIViewController? {
        guard let `controllers` = controllers else { return nil }
        guard controllers.count > 1 else { return nil }
        var previous: UIViewController?
        let index = controllers.firstIndex(of: viewController)
        if index != nil && index! != 0 {
            previous = controllers[index! - 1]
        }
        return previous
    }
    
    public func pageView(_ view: ISPageView, next viewController: UIViewController) -> UIViewController? {
        guard let `controllers` = controllers else { return nil }
        guard controllers.count > 1 else { return nil }
        var next: UIViewController?
        let index = controllers.firstIndex(of: viewController)
        if index != nil && index! != controllers.count - 1 {
            next = controllers[index! + 1]
        }
        return next
    }
}

// MARK: ISPageViewDelegate
extension ISPageMenu: ISPageViewDelegate {
    public func pageView(_ view: ISPageView, didScrollFrom src:UIViewController?, to dest: UIViewController, success: Bool) {
        guard success else { return }
        guard let `controllers` = controllers else { return }
        if let index = controllers.firstIndex(of: dest) {
            menuTabView.select(index: index, animated: true)
            delegate?.pageMenu?(self, didSelectAt: index)
        }
    }
}


// MARK: ISMenuTabViewDataSource, ISMenuTabViewDelegate
extension ISPageMenu: ISMenuTabViewDataSource, ISMenuTabViewDelegate {
    /// tab被选中时左边显示的图标
    public func menuTabViewSelectionMarkImage(_ view: ISMenuTabView) -> UIImage? {
        return dataSource?.pageMenuTabSelectionMarkImage?(self)
    }
    
    public func menuTabViewSelectionMarkImageHeight(_ view: ISMenuTabView) -> CGFloat {
        let height = dataSource?.pageMenuTabSelectionMarkImageHeight?(self)
        return height ?? -1
    }
    
    /// tab标签之间的最小间距
    public func menuTabViewMinimumItemSpacing(_ view: ISMenuTabView) -> CGFloat {
        let spacing = dataSource?.pageMenuMinimumTabSpacing?(self)
        return spacing ?? 20
    }
    
    /// 指定tab选中时的标题颜色
    public func menuTabView(_ view: ISMenuTabView, selectionTextColorAt index: NSInteger) -> UIColor? {
        return dataSource?.pageMenu?(self, tabSelectionTextColorAt: index)
    }
    
    /// 指定tab未选中时的标题颜色
    public func menuTabView(_ view: ISMenuTabView, deselectionTextColorAt index: NSInteger) -> UIColor? {
        return dataSource?.pageMenu?(self, tabDeselectionTextColorAt: index)
    }
    
    /// tab被选中时底部标识线的颜色
    public func menuTabViewIndicatorColor(_ view: ISMenuTabView) -> UIColor? {
        return dataSource?.pageMenuTabIndicatorColor?(self)
    }
    
    /// 指定选中tab标题字体
    public func menuTabViewTextFontSelected(_ view: ISMenuTabView) -> UIFont? {
        return dataSource?.pageMenuTabTextFontSelected?(self)
    }
    
    /// 指定未选中tab标题字体
    public func menuTabViewTextFontNormal(_ view: ISMenuTabView) -> UIFont? {
        return dataSource?.pageMenuTabTextFontNormal?(self)
    }
    
    /// 指定tab背景图
    public func menuTabView(_ view: ISMenuTabView, backgroundImageAt index: NSInteger) -> String? {
        return dataSource?.pageMenu?(self, tabBackgroundImageAt: index)
    }
    
    public func menuTabViewSegmentLineWidth(_ view: ISMenuTabView) -> CGFloat {
        let width = dataSource?.pageMenuTabSegmentLineWidth?(self)
        return width ?? 1
    }
    
    public func menuTabViewSegmentLineColor(_ view: ISMenuTabView) -> UIColor? {
        return dataSource?.pageMenuTabSegmentLineColor?(self)
    }
    
    /// 选中index位置的tab
    public func menuTabView(_ view: ISMenuTabView, didSelectAt index: NSInteger) {
        guard let `controllers` = controllers else { return }
        guard index >= 0 && index <= controllers.count - 1 else { return }
        if index > currentSelectionIndex {
            pageView.select(viewController: controllers[index], direction: .forward, animated: true)
        } else {
            pageView.select(viewController: controllers[index], direction: .backward, animated: true)
        }
    }
}

// MARK: ISPageMenuDataSource declaration
@objc public protocol ISPageMenuDataSource {
    
    /// tab被选中时左边显示的图标
    /// - Parameter view: ISPageMenu
    @objc optional func pageMenuTabSelectionMarkImage(_ view: ISPageMenu) -> UIImage?
    
    /// tab被选中时左边显示的图标高度; 不实现该方法或者值为负数，则高度根据容器高度自适应
    /// - Parameter view: ISPageMenu
    @objc optional func pageMenuTabSelectionMarkImageHeight(_ view: ISPageMenu) -> CGFloat
    
    /// tab标签之间的最小间距
    /// - Parameter view: ISPageMenu
    @objc optional func pageMenuMinimumTabSpacing(_ view: ISPageMenu) -> CGFloat
    
    /// 指定tab选中时的标题颜色，默认UIColor.red
    /// - Parameter view: ISPageMenu
    /// - Parameter index: tab所在位置索引
    @objc optional func pageMenu(_ view: ISPageMenu, tabSelectionTextColorAt index: NSInteger) -> UIColor?
    
    /// 指定tab未选中时的标题颜色，默认UIColor.gray
    /// - Parameter view: ISPageMenu
    /// - Parameter index: tab所在位置索引
    @objc optional func pageMenu(_ view: ISPageMenu, tabDeselectionTextColorAt index: NSInteger) -> UIColor?
    
    /// tab被选中时底部标识线的颜色，默认UIColor.red
    /// - Parameter view: ISPageMenu
    @objc optional func pageMenuTabIndicatorColor(_ view: ISPageMenu) -> UIColor?
    
    /// 指定选中tab标题字体
    /// - Parameter view: ISPageMenu
    @objc optional func pageMenuTabTextFontSelected(_ view: ISPageMenu) -> UIFont?
    
    /// 指定未选中tab标题字体
    /// - Parameter view: ISPageMenu
    @objc optional func pageMenuTabTextFontNormal(_ view: ISPageMenu) -> UIFont?
    
    /// 指定tab背景图
    /// - Parameter view: ISPageMenu
    /// - Parameter index: tab所在位置索引
    @objc optional func pageMenu(_ view: ISPageMenu, tabBackgroundImageAt index: NSInteger) -> String?
    
    /// segment样式下，tab之间分割线的颜色
    /// - Parameter view: ISPageMenu
    @objc optional func pageMenuTabSegmentLineColor(_ view: ISPageMenu) -> UIColor?
    
    /// segment样式下，tab之间分割线的宽度
    /// - Parameter view: ISMenuTabView
    @objc optional func pageMenuTabSegmentLineWidth(_ view: ISPageMenu) -> CGFloat
    
}

// MARK: ISPageMenuDelegate declaration
@objc public protocol ISPageMenuDelegate {
    /// 选中index位置的tab
    /// - Parameter view: ISPageMenu
    /// - Parameter index: index
    @objc optional func pageMenu(_ view: ISPageMenu, didSelectAt index: NSInteger)
}
