//
//  ISMenuTabView.swift
//  PageMenu
//
//  Created by jerrychen on 2019/10/11.
//  Copyright © 2019 jerrychen. All rights reserved.
//
//  以UICollectionView为载体实现tab标签视图
//

import UIKit

open class ISMenuTabView: UIView {
    
    // MARK: public properties
    @objc public weak var dataSource: ISMenuTabViewDataSource?
    
    @objc public weak var delegate: ISMenuTabViewDelegate?
    
    /// 标签填充视图窗口；设置为true，当tab内容+预设最小间距不足以撑满视图窗口时，会自动扩大间距以撑满。
    /// isSegmentStyle = true时，忽略该设置
    @objc public var isFillWindow: Bool = true
    
    /// 顶部tab标签呈现segment样式
    @objc public var isSegmentStyle: Bool = false
    
    /// tab外边距
    @objc public var reservedInsets: UIEdgeInsets = .zero {
        didSet {
            if tabCollectionView.superview != nil {
                tabCollectionView.snp.remakeConstraints { make in
                    make.left.equalTo(self).offset(reservedInsets.left)
                    make.right.equalTo(self).offset(-reservedInsets.right)
                    make.top.equalTo(self).offset(reservedInsets.top)
                    make.bottom.equalTo(self).offset(-reservedInsets.bottom)
                }
            }
            reload()
        }
    }
    
    /// indicator样式
    @objc public var indicatorStyle: ISMenuTabViewIndicatorStyle = .line
    
    /// 标题
    @objc public var tabTitles: [String]? {
        didSet {
            currentSelectionIndex = nil;
            reload()
        }
    }
    
    /// indicator样式定义
    @objc public enum ISMenuTabViewIndicatorStyle: UInt8 {
        case line //线条
        case fillBackground //背景填充
    }
    
    /// tab容器
    private lazy var tabCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.delegate = self
        view.dataSource = self
        view.register(ISMenuTabItem.classForCoder(), forCellWithReuseIdentifier: "ISMenuTabItem")
        return view
    }()
    
    /// 选中tab时，底部显示的横线标识
    private lazy var indicator: UIView = {
        let view = UIView()
        return view
    }()
    
    /// 当前选中tab的索引
    private var currentSelectionIndex: NSInteger?
    
    /// tab最小间距
    private var minimumItemSpacing: CGFloat = 0
    
    /// tab选中时左边图标的高度
    fileprivate var selectionMarkImageHeight: CGFloat = -1
    
    /// 标题宽度
    private var titleWidths: [CGFloat] = []
    
    /// 所有标题文本总宽度
    private var totalTitleWidth: CGFloat = 0
    
    /// selectionMarkImageDefault显示容器宽度
    private var selectionMarkImageWidth: CGFloat {
        var imageMarkWidth: CGFloat = 0
        if tabCollectionView.bounds.height <= 0 {
            return imageMarkWidth
        }
        if let `selectionMarkImageDefault` = selectionMarkImageDefault {
            imageMarkWidth = ISMenuTabItem.calculateSelectionMarkImageSize(selectionMarkImageDefault, expectHeight:selectionMarkImageHeight, maxHeight: tabCollectionView.bounds.height - 4).width
        }
        return imageMarkWidth
    }
    
    // MARK: 默认样式定义
    
    /// 默认item间距
    private var itemMinimumSpacingDefault: CGFloat = 20
    
    /// 默认选中tab时的标题颜色
    private var selectionTextColorDefault = UIColor.red
    
    /// 默认未选中tab时的标题颜色
    private var deselectionTextColorDefault = UIColor.gray
    
    /// 默认底部标识线的颜色
    private var indicatorColorDefault = UIColor.red
    
    /// 默认未选中tab字体 - 选中的tab字体如果通过代理设置则使用代理的值，否则使用该值
    private var textFontDefault = UIFont.systemFont(ofSize: 15)
    
    /// 选中tab后左边显示的图标
    private var selectionMarkImageDefault: UIImage?
    
    // MARK: init
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(tabCollectionView)
        tabCollectionView.addSubview(indicator)
        indicator.layer.zPosition = -1
        setupConstraints()
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        guard self.bounds.width > 0 else { return }
        calculateMinimumItemSpacing()
        if let index = currentSelectionIndex {
            currentSelectionIndex = nil;//重置index，目的是为了让select方法顺利执行刷新动作
            select(index: index, animated: false)
        }
    }
}

// MARK: public methods
extension ISMenuTabView {
    
    /// 选择指定索引tab
    /// - Parameter index: tab索引
    @objc public func select(index: NSInteger, animated: Bool) {
        guard let `tabTitles` = tabTitles else { return }
        guard index >= 0 && index < tabTitles.count else { return }
        guard self.bounds.width > 0 else {
            //记录index，待时机成熟再尝试刷新
            currentSelectionIndex = index
            return
        }
        if currentSelectionIndex != index {
            currentSelectionIndex = index
            if ((dataSource?.menuTabViewTextFontSelected?(self)) != nil) {
                reload()
            }else {
                tabCollectionView.reloadData()
            }
        }

        tabCollectionView.bringSubviewToFront(indicator)
        //scroll to visible
        let indexPath = IndexPath(row: index, section: 0)
        tabCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        //indicator
        tabCollectionView.layoutIfNeeded()
        guard let cell = tabCollectionView.cellForItem(at: indexPath) as? ISMenuTabItem else { return }
        let titleFrame = cell.titleLabel.frame
        let point = cell.convert(titleFrame.origin, to: tabCollectionView)
        let textSize = cell.titleLabel.textRect(forBounds: cell.titleLabel.bounds, limitedToNumberOfLines: 1)
        let x = point.x + titleFrame.size.width/2.0 - textSize.width/2.0
        if indicatorStyle == .line {
            self.indicator.layer.cornerRadius = 0
            if animated {
                UIView.animate(withDuration: 0.3) {
                    self.indicator.frame = CGRect(x: x, y: cell.frame.height - 2, width: textSize.width, height: 2)
                }
            } else {
                self.indicator.frame = CGRect(x: x, y: cell.frame.height - 2, width: textSize.width, height: 2)
            }
        } else {
            indicator.layer.cornerRadius = textSize.height/2.0
            indicator.layer.masksToBounds = true
            let y = point.y + titleFrame.size.height/2.0 - textSize.height/2.0
            if animated {
                UIView.animate(withDuration: 0.3) {
                    self.indicator.frame = CGRect(x: x - 5, y: y, width: textSize.width + 10, height: textSize.height)
                }
            } else {
                indicator.frame = CGRect(x: x - 5, y: y, width: textSize.width + 10, height: textSize.height)
            }
        }
    }
    
    /// 当tab样式源有变更时调用重刷
    @objc public func refreshDisplay() {
        reload();
    }
}

// MARK: private methods
extension ISMenuTabView {
    private func setupConstraints() {
        tabCollectionView.snp.makeConstraints { make in
            make.left.equalTo(self).offset(reservedInsets.left)
            make.right.equalTo(self).offset(-reservedInsets.right)
            make.top.equalTo(self).offset(reservedInsets.top)
            make.bottom.equalTo(self).offset(-reservedInsets.bottom)
        }
    }
    
    /// 重载内容数据
    private func reload() {
        selectionMarkImageDefault = dataSource?.menuTabViewSelectionMarkImage?(self)
        if let height = dataSource?.menuTabViewSelectionMarkImageHeight?(self) {
            selectionMarkImageHeight = height
        } else {
            selectionMarkImageHeight = -1
        }
        calculateTitlesWidth()
        setNeedsLayout()
        tabCollectionView.reloadData()
        tabCollectionView.bringSubviewToFront(indicator)
    }
    
    /// 计算并缓存标题宽度
    private func calculateTitlesWidth() {
        titleWidths.removeAll()
        totalTitleWidth = 0
        guard let `tabTitles` = tabTitles else { return }
        titleWidths = tabTitles.map({ (element, index) in
            var font = dataSource?.menuTabViewTextFontNormal?(self)
            font = font ?? textFontDefault
            if index == currentSelectionIndex {
                let fontSelected = dataSource?.menuTabViewTextFontSelected?(self)
                font = fontSelected ?? font
            }
            return NSString(string: element).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: font!.lineHeight), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font!], context: nil).width + 5
        })
        totalTitleWidth = titleWidths.reduce(0, +)
    }
    
    private func calculateMinimumItemSpacing() {
        if isSegmentStyle {
            minimumItemSpacing = 0
        } else {
            let spacing = dataSource?.menuTabViewMinimumItemSpacing?(self)
            minimumItemSpacing = spacing ?? itemMinimumSpacingDefault
            if isFillWindow && titleWidths.count > 0 {
                let perMinimumItemSpacing = (tabCollectionView.frame.width - totalTitleWidth - selectionMarkImageWidth - (selectionMarkImageWidth > 0 ? 5 : 0)) / CGFloat(titleWidths.count + 1)
                minimumItemSpacing = max(minimumItemSpacing, perMinimumItemSpacing)
            }
        }
        //
        if tabCollectionView.contentInset.left != minimumItemSpacing || tabCollectionView.contentInset.right != minimumItemSpacing {
            tabCollectionView.contentInset = UIEdgeInsets(top: 0, left: minimumItemSpacing, bottom: 0, right: minimumItemSpacing)
        }
    }
}

// MARK: UICollectionViewDataSource, UICollectionViewDelegate
extension ISMenuTabView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard indexPath.row >= 0 && indexPath.row < titleWidths.count else {
            return .zero
        }
        if isSegmentStyle {
            return CGSize(width: collectionView.bounds.width/CGFloat(titleWidths.count), height: collectionView.bounds.height)
        }
        if isFillWindow && titleWidths.count == 1 {
            return CGSize(width: collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right, height: collectionView.bounds.height)
        }
        if currentSelectionIndex != nil && currentSelectionIndex! == indexPath.row {
            //选中
            return CGSize(width: titleWidths[indexPath.row] + selectionMarkImageWidth + (selectionMarkImageWidth > 0 ? 5 : 0), height: collectionView.bounds.height)
        } else {
            return CGSize(width: titleWidths[indexPath.row], height: collectionView.bounds.height)
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let `tabTitles` = tabTitles else {
            return 0
        }
        return tabTitles.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return minimumItemSpacing
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return minimumItemSpacing
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ISMenuTabItem", for: indexPath) as! ISMenuTabItem
        cell.selectionMarkImageHeight = selectionMarkImageHeight
        //segment
        if isSegmentStyle && tabTitles != nil {
            cell.isShowSegmentLine = indexPath.row < tabTitles!.count - 1
            cell.segmentLine.backgroundColor = dataSource?.menuTabViewSegmentLineColor?(self)
            if let width = dataSource?.menuTabViewSegmentLineWidth?(self) {
                cell.segmentLineWidth = width
            }
        }
        //标题文本
        if tabTitles != nil && indexPath.row >= 0 && indexPath.row < tabTitles!.count {
            cell.titleLabel.text = tabTitles![indexPath.row]
        }
        //背景图
        if let bgImageUrl = dataSource?.menuTabView?(self, backgroundImageAt: indexPath.row) {
            cell.bgImageView.sd_setImage(with: URL(string: bgImageUrl), completed: nil)
            cell.bgImageView.isHidden = false
        } else {
            cell.bgImageView.isHidden = true
        }
        //
        if currentSelectionIndex != nil && currentSelectionIndex! == indexPath.row {
            //选中
            //1、标题颜色
            let color = dataSource?.menuTabView?(self, selectionTextColorAt: indexPath.row)
            cell.titleLabel.textColor = color ?? selectionTextColorDefault
            //2、indicator颜色
            let indicatorColor = dataSource?.menuTabViewIndicatorColor?(self)
            indicator.backgroundColor = indicatorColor ?? indicatorColorDefault
            //3、tab选中时左边的图标
            if !isSegmentStyle {
                cell.selectionMarkImageView.image = selectionMarkImageDefault
            }
            //4、字体
            let font = dataSource?.menuTabViewTextFontSelected?(self)
            cell.titleLabel.font = font ?? textFontDefault
            cell.select()
        } else {
            //未选中
            //1、标题颜色
            let color = dataSource?.menuTabView?(self, deselectionTextColorAt: indexPath.row)
            cell.titleLabel.textColor = color ?? deselectionTextColorDefault
            //2、字体
            let font = dataSource?.menuTabViewTextFontNormal?(self)
            cell.titleLabel.font = font ?? textFontDefault
            cell.deselect()
        }
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if currentSelectionIndex != indexPath.row {
            select(index: indexPath.row, animated: true)
            delegate?.menuTabView?(self, didSelectAt: indexPath.row)
        }
    }
}

// MARK: ISMenuTabViewDataSource declaration
@objc public protocol ISMenuTabViewDataSource {
    
    /// tab被选中时左边显示的图标
    /// - Parameter view: ISMenuTabView
    @objc optional func menuTabViewSelectionMarkImage(_ view: ISMenuTabView) -> UIImage?
    
    /// tab被选中时左边显示的图标的高度；不实现该方法或者值为负数，则高度根据容器高度自适应
    /// - Parameter view: ISMenuTabView
    @objc optional func menuTabViewSelectionMarkImageHeight(_ view: ISMenuTabView) -> CGFloat;
    
    /// tab标签之间的最小间距
    /// - Parameter view: ISMenuTabView
    @objc optional func menuTabViewMinimumItemSpacing(_ view: ISMenuTabView) -> CGFloat
    
    /// 指定tab选中时的标题颜色，默认UIColor.red
    /// - Parameter view: ISMenuTabView
    /// - Parameter index: tab所在位置索引
    @objc optional func menuTabView(_ view: ISMenuTabView, selectionTextColorAt index: NSInteger) -> UIColor?
    
    /// 指定tab未选中时的标题颜色，默认UIColor.gray
    /// - Parameter view: ISMenuTabView
    /// - Parameter index: tab所在位置索引
    @objc optional func menuTabView(_ view: ISMenuTabView, deselectionTextColorAt index: NSInteger) -> UIColor?
    
    /// tab被选中时底部标识线的颜色，默认UIColor.red
    /// - Parameter view: ISMenuTabView
    @objc optional func menuTabViewIndicatorColor(_ view: ISMenuTabView) -> UIColor?
    
    /// 指定选中tab标题字体
    /// - Parameter view: ISMenuTabView
    @objc optional func menuTabViewTextFontSelected(_ view: ISMenuTabView) -> UIFont?
    
    /// 指定未选中tab标题字体
    /// - Parameter view: ISMenuTabView
    @objc optional func menuTabViewTextFontNormal(_ view: ISMenuTabView) -> UIFont?
    
    /// 指定tab背景图
    /// - Parameter view: ISMenuTabView
    /// - Parameter index: tab所在位置索引
    @objc optional func menuTabView(_ view: ISMenuTabView, backgroundImageAt index: NSInteger) -> String?
    
    /// segment样式下，tab之间分割线的颜色
    /// - Parameter view: ISMenuTabView
    @objc optional func menuTabViewSegmentLineColor(_ view: ISMenuTabView) -> UIColor?
    
    /// segment样式下，tab之间分割线的宽度
    /// - Parameter view: ISMenuTabView
    @objc optional func menuTabViewSegmentLineWidth(_ view: ISMenuTabView) -> CGFloat
    
}

// MARK: ISMenuTabViewDelegate declaration
@objc public protocol ISMenuTabViewDelegate {
    
    /// 选中index位置的tab
    /// - Parameter view: ISMenuTabView
    /// - Parameter index: index
    @objc optional func menuTabView(_ view: ISMenuTabView, didSelectAt index: NSInteger)
    
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////

// MARK: class ISMenuTabItem
private class ISMenuTabItem: UICollectionViewCell {
    
    /// 选中tab时，左边显示的图片标记
    fileprivate lazy var selectionMarkImageView: FLAnimatedImageView = {
        let view = FLAnimatedImageView()
        view.contentMode = .scaleToFill
        view.isHidden = true
        return view
    }()
    
    /// 背景图
    fileprivate lazy var bgImageView: FLAnimatedImageView = {
        let view = FLAnimatedImageView()
        view.contentMode = .scaleToFill
        return view
    }()
    
    /// tab标题
    fileprivate lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = .center
        view.backgroundColor = .clear
        view.layer.masksToBounds = true
        return view
    }()
    
    fileprivate lazy var segmentLine: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        view.isHidden = true
        return view
    }()
    
    fileprivate var segmentLineWidth: CGFloat = 1 {
        didSet {
            guard oldValue != segmentLineWidth else { return }
            segmentLine.snp.updateConstraints { make in
                make.width.equalTo(segmentLineWidth)
            }
            layoutIfNeeded()
        }
    }
    
    fileprivate var isShowSegmentLine: Bool = false {
        didSet {
            guard oldValue != isShowSegmentLine else { return }
            segmentLine.isHidden = !isShowSegmentLine
            titleLabel.snp.updateConstraints {make in
                if isShowSegmentLine {
                    make.right.equalTo(contentView).offset(-segmentLineWidth)
                } else {
                    make.right.equalTo(contentView).offset(0)
                }
            }
            layoutIfNeeded()
        }
    }
    
    /// tab选中时左边图标的高度
    fileprivate var selectionMarkImageHeight: CGFloat = -1
    
    // MARK: init
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        contentView.addSubview(bgImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(selectionMarkImageView)
        contentView.addSubview(segmentLine)
        setupConstraints()
    }
}

// MARK: public methods
extension ISMenuTabItem {
    
    /// 选中当前tab
    public func select() {
        guard let image = selectionMarkImageView.image else { return }
        let imageSize = ISMenuTabItem.calculateSelectionMarkImageSize(image, expectHeight:selectionMarkImageHeight, maxHeight: contentView.bounds.height - 4)
        selectionMarkImageView.isHidden = false
        selectionMarkImageView.snp.updateConstraints { make in
            make.height.equalTo(imageSize.height)
            make.width.equalTo(imageSize.width)
        }
        titleLabel.snp.updateConstraints { make in
            make.left.equalTo(selectionMarkImageView.snp.right).offset(5)
        }
        contentView.layoutIfNeeded()
    }
    
    /// 反选当前tab
    public func deselect() {
        selectionMarkImageView.isHidden = true
        guard selectionMarkImageView.image != nil else { return }
        selectionMarkImageView.snp.updateConstraints { make in
            make.width.equalTo(0)
        }
        titleLabel.snp.updateConstraints { make in
            make.left.equalTo(selectionMarkImageView.snp.right).offset(0)
        }
        contentView.layoutIfNeeded()
    }
}

// MARK: private methods
extension ISMenuTabItem {
    
    private func setupConstraints() {
        bgImageView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
        selectionMarkImageView.snp.makeConstraints { make in
            make.left.centerY.equalTo(contentView)
            make.height.equalTo(15)
            make.width.equalTo(0)
        }
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(selectionMarkImageView.snp.right).offset(0)
            make.top.bottom.equalTo(contentView)
            make.right.equalTo(contentView).offset(0)
        }
        segmentLine.snp.makeConstraints {make in
            make.right.centerY.equalTo(contentView)
            make.width.equalTo(segmentLineWidth)
            make.height.equalTo(contentView).multipliedBy(0.6)
        }
    }
    
    /// 给定cell高度，计算MarkImage的显示尺寸；expectHeight为负高度根据maxHeight自适应
    /// - Parameter image: MarkImage
    /// - Parameter expectHeight: 期望高度
    /// - Parameter maxHeight: cell最大高度
    fileprivate class func calculateSelectionMarkImageSize(_ image: UIImage, expectHeight: CGFloat ,maxHeight: CGFloat) -> CGSize {
        let imageSize = image.size
        var height = maxHeight - 4
        if expectHeight >= 0 && expectHeight <= maxHeight {
            height = expectHeight
        }
        let width = imageSize.width / imageSize.height * height
        return CGSize(width: width, height: height)
    }
}

extension Array {
    func map<ElementOfResult>(_ transform: (Element, Int) throws -> ElementOfResult) rethrows -> [ElementOfResult] {
        var array: Array<ElementOfResult> = []
        for index in 0..<self.count {
            array.append(try transform(self[index], index))
        }
        return array
    }
}
