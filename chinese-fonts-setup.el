;;; chinese-fonts-setup.el --- 实现中英文字体等宽对齐的字体配置工具。

;; Copyright (c) 2011-2014, Feng Shu

;; Author: Feng Shu <tumashu@gmail.com>
;; URL: https://github.com/tumashu/chinese-fonts-setup
;; Version: 0.0.1

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; `chinese-fonts-setup' 是一个emacs中文字体配置工具。可以比较方便的
;; 的实现中文字体和英文字体等宽（也就是大家常说的中英文对齐）。
;;
;; 这个package特别适用于需要处理中英文混合表格的中文org-mode用户。
;;
;; ### 过程展示 ###
;;
;;     http://www.tudou.com/programs/view/v7Kr0_a9INw/
;;
;; ### 下载 ###
;;
;;     https://github.com/tumashu/chinese-fonts-setup
;;
;; ### 安装 ###
;; 将这个文件放到任意一个emacs搜索目录之下，然后在~/.emacs中添加：
;;
;;     (require 'chinese-fonts-setup)
;;
;; ### 配置 ###
;; chinese-fonts-setup 使用profile的概念，来实现特定的环境使用特定的
;; 字体配置，比如：在编程时使用 “Consolas + 微米黑”，在阅读文章时使用
;; “PragmataPro + 黑体”。
;;
;; 每一个profile都是一个emacs-lisp文件。其中包括了英文字体设置，中文字体设置
;; 以及中文字体调整系数（scale）。

;; chinese-fonts-setup 默认使用三个profile: profile1, profile2 和 profile3,
;; 如果想使用其他有意义的名称，可以使用下面类似的方式配置:
;;
;;      (setq cfs-profiles
;;            '("program" "org-mode" "read-book"))
;;
;; profile文件保存在`cfs-profiles-directory'对应的目录中。如果文件不存在，
;; chinese-fonts-setup 在切换 profile 时通过自带的falback信息创建一个。
;;
;; 切换 profile 的命令有：
;;
;; 1. `cfs-select-profile' (通过参数选择profile，可用于用户自定义profile切换命令)
;; 2. `cfs-switch-profile' (选择profile)
;; 3. `cfs-next-profile'   (直接切换到下一个profile)
;;
;; 如果当前的profile不适合时，可以通过`cfs-edit-profile'来编辑当前
;; 的profile文件。chinese-fonts-setup自带一个profile-edit编辑模式。
;;
;; 1.  C-c C-c     `cfs-test-fontscale-at-point'
;;                  察看字体显示效果
;; 2.  C-<up>      `cfs-increment-fontscale-at-point'
;;                  增大光标下的scale数字，同时显示增加后的字体对齐效果
;; 3.  C-<down>    `cfs-decrement-fontscale-at-point'
;;                  减小光标下的scale数字，同时显示减小后的字体对齐效果
;;
;; ### 调整字体大小 ###
;; `chinese-fonts-setup' 使用下述两个命令调整字体大小:
;;
;; 1.  `cfs-increase-fontsize' 增大字体大小
;; 2.  `cfs-decrease-fontsize' 减小字体大小
;;
;; 在调整字体大小的同时，字号信息也通过customize-save-variable函数保存到~/.emacs中了。
;;
;; ### 使用斜体和粗斜体 ###
;; `chinese-fonts-setup' 默认使用正常字体代替斜体，粗体代替粗斜体。这样设置的原因是：
;; 大多数英文等宽字体包含的斜体不能将(9 10.5 11.5 12.5 14 16 18 20 22)这几个字号完全覆盖。
;; 如果想使用斜体和粗斜体，请使用下面的设置：
;;
;;       (setq cfs-ignore-italic nil)
;;       (setq cfs-ignore-bold-italic nil)
;;
;; 与此同时，你要使用一个包含粗体和粗斜体的英文等宽字体。
;;
;; ### 参考文章 ###
;;
;; http://baohaojun.github.io/perfect-emacs-chinese-font.html
;; http://zhuoqiang.me/torture-emacs.html

;;; Code:
(require 'cl)
(require 'ido)

(defcustom cfs-profiles '("profile1" "profile2" "profile3")
  "Lists chinese-fonts-setup profiles"
  :group 'chinese-fonts-setup
  :type 'list)

(defcustom cfs-profiles-directory "~/.emacs.d/cfs-profiles.d/"
  "*Directory variable from which all other chinese-fonts-setup profiles are derived."
  :group 'chinese-fonts-setup
  :type 'directory)

(defcustom cfs-ignore-italic t
  "使用正常代替斜体。"
  :group 'chinese-fonts-setup
  :type 'boolean)

(defcustom cfs-ignore-bold-italic t
  "使用粗体代替粗斜体。"
  :group 'chinese-fonts-setup
  :type 'boolean)

(defvar cfs--current-profile-name (car cfs-profiles)
  "Current profile name used by chinese-fonts-setup")

(defconst cfs--fontsize-fallback 12.5)

(defvar cfs--profiles-fontsizes
  (mapcar (lambda (x)
            cfs--fontsize-fallback) cfs-profiles)
  "fontsizes list of all profiles.")

(defconst cfs--fontsizes-steps
  '(9 10.5 11.5 12.5 14 16 18 20 22))

(defconst cfs--fontscales-fallback
  '(1.05 1.05 1.10 1.10 1.10 1.05 1.00 1.05 1.05))

(defconst cfs--fontnames-fallback
  '(("PragmataPro" "Monaco" "Consolas" "Menlof" "DejaVu Sans Mono"
     "Droid Sans Mono Pro" "Droid Sans Mono" "Inconsolata" "Source Code Pro"
     "Lucida Console" "Envy Code R" "Andale Mono" "Lucida Sans Typewriter"
     "monoOne" "Lucida Typewriter" "Panic Sans" "Bitstream Vera Sans Mono"
     "HyperFont" "PT Mono" "Ti92Pluspc" "Excalibur Monospace" "Courier New"
     "Courier" "Cousine" "Fira Mono" "Lekton" "Ubuntu Mono" "Liberation Mono"
     "M+ 1mn" "BPmono" "Free Mono" "Anonymous Pro" "ProFont" "ProFontWindows"
     "Latin Modern Mono" "Code 2002" "ProggyCleanTT" "ProggyTinyTT")
    ("黑体" "文泉驿等宽微米黑" "Microsoft Yahei" "Microsoft_Yahei" "微软雅黑"
     "Hiragino Sans GB" "文泉驿等宽正黑" "文泉驿正黑" "文泉驿点阵正黑"
     "新宋体" "宋体" "楷体_GB2312" "仿宋_GB2312" "幼圆" "隶书"
     "方正姚体" "方正舒体" "方正粗圆_GBK" "华文仿宋" "华文中宋" "华文彩云"
     "华文新魏" "华文细黑" "华文行楷")
    ("PragmataPro" "Courier New")))

(defconst cfs--test-string "
;; 请看下面中文和英文能否对齐.
;; +----------------------------------+
;; |  天生我材必有用，千金散尽还复来。|  (^_/)
;; |  abcdefghigklmnopqrstuvwxyz,.?!  | (='.'=)
;; | *abcdefghigklmnopqrstuvwxyz,.?!* | (0)_(0)
;; | /abcdefghigklmnopqrstuvwxyz,.?!/ |
;; +----------------------------------+
")

(defun cfs--get-current-profile ()
  (let ((directory-name
         (expand-file-name
          (file-name-as-directory cfs-profiles-directory))))
    (make-directory directory-name t)
    (concat directory-name
            cfs--current-profile-name ".el")))

(defun cfs--dump-variable (variable-name value)
  "Insert a \"(setq VARIABLE value)\" in the current buffer."
  (cond ((atom value)
         (insert (format "\n(setq %s %S)\n" variable-name value)))
        ((atom (car value))
         (insert (format "\n(setq %s\n       '%S)\n" variable-name value)))
        (t (insert (format "\n(setq %s\n      '(" variable-name))
           (dolist (e value)
             (insert (format "\n        %S" e)))
           (insert "\n       ))\n"))))

(defun cfs--save-current-profile-fontsize (profile-name size)
  (let* ((profiles-names cfs-profiles)
         (profiles-fontsizes cfs--profiles-fontsizes)
         (length1 (length profiles-names))
         (length2 (length profiles-fontsizes))
         (index (position profile-name cfs-profiles :test #'string=)))
    (if (= length1 length2)
        (setf (nth index profiles-fontsizes) size)
      (setq profiles-fontsize
            (mapcar (lambda (x)
                      cfs--fontsize-fallback) profiles-names)))
    (setq cfs--profiles-fontsizes profiles-fontsizes)
    (customize-save-variable 'cfs--profiles-fontsizes profiles-fontsizes)))

(defun cfs--read-current-profile-fontsize (profile-name)
  (let ((index (position profile-name cfs-profiles :test #'string=)))
    (nth index cfs--profiles-fontsizes)))

(defun cfs--save-profile (fonts-names fonts-scales)
  "Save fonts names and scales to current profile"
  (let ((variable-fonts-names "cfs--custom-set-fonts-names")
        (variable-fonts-scales "cfs--custom-set-fonts-scales"))
    (with-temp-buffer
      (erase-buffer)
      (insert ";;; 设置默认字体列表，按`C-c C-c'测试字体显示效果")
      (cfs--dump-variable variable-fonts-names  fonts-names)
      (insert (format "\n;;; 为每个字号%s设置中文调整系数，使中英文等宽度。"
                      cfs--fontsizes-steps))
      (cfs--dump-variable variable-fonts-scales fonts-scales)
      (write-file (cfs--get-current-profile)))))

(defun cfs--read-profile ()
  "Get previously saved fonts names and scales from current profile"
  (interactive)
  (let ((file (cfs--get-current-profile)))
    (when (file-readable-p file)
      (load-file file))
    (list (if (boundp 'cfs--custom-set-fonts-names)
              cfs--custom-set-fonts-names
            cfs--fontnames-fallback)
          (if (boundp 'cfs--custom-set-fonts-scales)
              cfs--custom-set-fonts-scales
            cfs--fontscales-fallback))))

(defun cfs--font-exists-p (font)
  (if (null (x-list-fonts font))
      nil t))

(defun cfs--get-valid-fonts ()
  (mapcar (lambda (x)
            (find-if #'cfs--font-exists-p x))
          (car (cfs--read-profile))))

(defun cfs--make-font-string (fontname fontsize)
  (if (and (stringp fontsize)
           (equal ":" (string (elt fontsize 0))))
      (format "%s%s" fontname fontsize)
    (format "%s-%s" fontname fontsize)))

(defun cfs--get-scale (&optional size)
  (let* ((scale-list (car (cdr (cfs--read-profile))))
         (index (or (position size cfs--fontsizes-steps) 1)))
    (unless (file-exists-p (cfs--get-current-profile))
      (message "如果中英文不能对齐，请运行`cfs-edit-profile'编辑当前profile。"))
    (or (nth index scale-list) 1)))

(defun cfs--set-font (fontsize &optional fontscale)
  (setq face-font-rescale-alist
        (mapcar (lambda (x)
                  (cons x (or fontscale 1.25)))
                (nth 1 (car (cfs--read-profile)))))
  (cfs--set-font-internal fontsize))

(defun cfs--set-font-internal (fontsize)
  "english-fontsize could be set to \":pixelsize=18\" or a integer.
If set/leave chinese-fontsize to nil, it will follow english-fontsize"
  (let* ((valid-fonts (cfs--get-valid-fonts))
         (english-main-font (cfs--make-font-string (nth 0 valid-fonts) fontsize))
         (chinese-main-font (font-spec :family (nth 1 valid-fonts)))
         (english-bold-font
          (font-spec :slant 'normal :weight 'bold
                     :size fontsize
                     :family (nth 0 valid-fonts)))
         (english-italic-font
          (font-spec :slant 'italic :weight 'normal
                     :size fontsize
                     :family (nth 0 valid-fonts)))
         (english-bold-italic-font
          (font-spec :slant 'italic :weight 'bold
                     :size fontsize
                     :family (nth 0 valid-fonts)))
         (english-symbol-font (font-spec :family (nth 3 valid-fonts))))
    (set-face-attribute 'default nil :font english-main-font)
    (set-face-font 'italic
                   (if cfs-ignore-italic
                       english-main-font
                     english-italic-font))
    (set-face-font 'bold-italic
                   (if cfs-ignore-bold-italic
                       english-bold-font
                     english-bold-italic-font))
    (set-fontset-font t 'symbol english-symbol-font)
    (set-fontset-font t nil (font-spec :family "DejaVu Sans"))

    ;; Set Chinese font and don't not use 'unicode charset,
    ;; it will cause the english font setting invalid.
    (dolist (charset '(kana han cjk-misc bopomofo))
      (set-fontset-font t charset chinese-main-font))))

(defun cfs--step-fontsize (step)
  (let* ((profile-name cfs--current-profile-name)
         (steps cfs--fontsizes-steps)
         (current-size (cfs--read-current-profile-fontsize profile-name))
         next-size)
    (when (< step 0)
      (setq steps (reverse cfs--fontsizes-steps)))
    (setq next-size
          (cadr (member current-size steps)))
    (when next-size
      (cfs--set-font next-size (cfs--get-scale next-size))
      (cfs--save-current-profile-fontsize profile-name next-size)
      (message "Your font size is set to %.1f" next-size))))

(defun cfs-set-font-with-saved-size ()
  (let* ((profile-name cfs--current-profile-name)
         (fontsize (cfs--read-current-profile-fontsize profile-name))
         (fontsize-scale (cfs--get-scale fontsize)))
    (when (display-graphic-p)
      (cfs--set-font fontsize fontsize-scale))))

;; 正常启动emacs时设置字体
(if (and (fboundp 'daemonp) (daemonp))
    (add-hook 'after-make-frame-functions
              (lambda (frame)
                (with-selected-frame frame
                  (cfs-set-font-with-saved-size))))
  (cfs-set-font-with-saved-size))

(defun cfs-decrease-fontsize ()
  (interactive)
  (cfs--step-fontsize -1))

(defun cfs-increase-fontsize ()
  (interactive)
  (cfs--step-fontsize 1))

(defvar cfs-profile-edit-mode-map
  (let ((keymap (make-sparse-keymap)))
    (define-key keymap "\C-c\C-c" 'cfs-test-fontscale-at-point)
    (define-key keymap (kbd "C-<up>") 'cfs-increment-fontscale-at-point)
    (define-key keymap (kbd "C-<down>") 'cfs-decrement-fontscale-at-point)
    (define-key keymap (kbd "C-<right>") 'cfs-increment-fontscale-at-point)
    (define-key keymap (kbd "C-<left>") 'cfs-decrement-fontscale-at-point)
    keymap)
  "Keymap for `cfs-profile-edit-mode', a minor mode used to setup fonts names and scales")

(define-minor-mode cfs-profile-edit-mode
  "Minor for setup fonts names and scales"
  nil " Rem" cfs-profile-edit-mode-map)

(defun cfs-select-profile (profile-name)
  (setq cfs--current-profile-name profile-name)
  (customize-save-variable 'cfs--current-profile-name profile-name)
  (cfs-set-font-with-saved-size))

(defun cfs-switch-profile ()
  (interactive)
  (let ((profile
         (ido-completing-read "Set chinese-fonts-setup profile to:" cfs-profiles)))
    (cfs-select-profile profile)))

(defun cfs-next-profile (&optional step)
  (interactive)
  (let ((profiles cfs-profiles)
        (current-profile cfs--current-profile-name)
        next-profile)
    (setq next-profile
          (or (cadr (member current-profile profiles))
              (car profiles)))
    (when next-profile
      (setq cfs--current-profile-name next-profile)
      (customize-save-variable 'cfs--current-profile-name next-profile))
    (when (display-graphic-p)
      (cfs-set-font-with-saved-size))
    (message "Current chinese-fonts-setup profile is set to: \"%s\"" next-profile)))

(defun cfs-edit-profile ()
  (interactive)
  (let ((file (cfs--get-current-profile)))
    (unless (file-readable-p file)
      (cfs--save-profile cfs--fontnames-fallback
                         cfs--fontscales-fallback))
    (find-file file)
    (cfs-profile-edit-mode 1)
    (goto-char (point-min))))

(defun cfs-test-fontscale-at-point ()
  "Test scale list at point, which is usd to write font scale list"
  (interactive)
  (let (scale size index)
    (setq scale (sexp-at-point))
    (if (and scale (numberp scale))
        (progn
          (setq index
                (save-excursion
                  (let* ((point1 (point))
                         (point2 (progn (search-backward "(")
                                        (point))))
                    (length (split-string
                             (buffer-substring-no-properties point1 point2)
                             " ")))))
          (setq size (nth (1- index) cfs--fontsizes-steps))
          (cfs--set-font size scale)
          (cfs--show-font-effect size scale))
      (cfs--set-font 14 1.25)
      (cfs--show-font-effect 14 1.25 t))))

(defun cfs-change-fontscale-at-point (step)
  (interactive)
  (skip-chars-backward "0123456789\\.")
  (or (looking-at "[0123456789.]+")
      (error "No number at point"))
  (replace-match
   (format "%.5s"
           (number-to-string
            (+ step (string-to-number (match-string 0))))))
  (backward-char 1)
  (cfs-test-fontscale-at-point))

(defun cfs-increment-fontscale-at-point ()
  (interactive)
  (cfs-change-fontscale-at-point 0.01))

(defun cfs-decrement-fontscale-at-point ()
  (interactive)
  (cfs-change-fontscale-at-point -0.01))

(defun cfs--show-font-effect (&optional size scale info)
  "show font and its size in a new buffer"
  (interactive)
  (let ((buffer-name "*Show-font-effect*"))
    (with-output-to-temp-buffer buffer-name
      (set-buffer buffer-name)
      (when (featurep 'org)
        (org-mode))
      (setq truncate-lines 1)
      (when size
        (insert (format "# 英文字体大小设置为: %s ; " size)))
      (when scale
        (insert (format "中文字体调整系数(scale)设置为: %s 。\n" scale)))
      (when info
        (insert
         (concat
          "# 将光标移动到`cfs--custom-set-fonts-scales‘中各个数字上，"
          "C-<up> 增大 scale 的值，C-<down> 减小 scale 的值。")))
      (insert
       (replace-regexp-in-string
        "\\^"  "\\\\"
        (replace-regexp-in-string
         "@@"  "   "
         cfs--test-string)))
      (when (and size scale)
        (cfs--set-font size scale)))))

;;;###autoload(require 'chinese-fonts-setup)
(provide 'chinese-fonts-setup)

;; Local Variables:
;; coding: utf-8-unix
;; End:

;;; chinese-fonts-setup.el ends here
