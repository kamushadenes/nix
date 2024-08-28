(setq user-full-name "Henrique Goncalves"
      user-mail-address "kamus@hadenes.io")

(setq doom-font (font-spec :family "MonaspiceNe Nerd Font Mono" :size 14 :weight 'medium))

(setq catppuccin-flavor 'macchiato)
(setq doom-theme 'catppuccin)

(setq centaur-tabs-style "wave")
(setq centaur-tabs-set-icons t)
(setq centaur-tabs-set-bar 'under)
(setq x-underline-at-descent-line t)
(setq centaur-tabs-set-modified-marker t)


;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;;(add-to-list 'org-structure-template-alist '("<" . "src emacs-lisp"))

;;(define-key org-mode-map "\<" 'org-insert-structure-template)

(after! flycheck
  (setq flycheck-check-syntax-automatically '(save idle-change new-line mode-enabled)))

(shx-global-mode 1)

(global-wakatime-mode)
(setq wakatime-cli-path (concat (getenv "NIX_HM_PROFILE") "/bin/wakatime-cli"))

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

(indent-according-to-mode)

;; Visual / line wrap
(global-visual-line-mode)

;; Present buffers on window split
(setq evil-vsplit-window-right t
      evil-split-window-below t)

(setq undo-limit 80000000                         ; Raise undo-limit to 80Mb
      evil-want-fine-undo t                       ; By default while in insert all changes are one big blob. Be more granular
      )

;; which-key
(setq which-key-idle-delay 0.5) ;; I need the help, I really do

;; info-colors
(add-hook 'Info-selection-hook 'info-colors-fontify-node)
(add-hook 'Info-mode-hook #'mixed-pitch-mode)

(setq which-key-allow-multiple-replacements t)
(after! which-key
  (pushnew!
   which-key-replacement-alist
   '(("" . "\\`+?evil[-:]?\\(?:a-\\)?\\(.*\\)") . (nil . "◂\\1"))
   '(("\\`g s" . "\\`evilem--?motion-\\(.*\\)") . (nil . "◃\\1"))
   ))

(setq yas-snippet-dirs (append yas-snippet-dirs
                               '("~/.doom.d/snippets")))

(setq-default history-length 1000)
(setq-default prescient-history-length 1000)

(custom-set-variables
 '(with-editor-emacsclient-executable (concat (getenv "NIX_HM_PROFILE") "/bin/emacsclient")))
(after! magit
  (setq magit-revision-show-gravatars '("^Author:     " . "^Commit:     ")))


(set-file-template! "\\.tex$" :trigger "__" :mode 'latex-mode)
(set-file-template! "\\.org$" :trigger "__" :mode 'org-mode)
(set-file-template! "/LICEN[CS]E$" :trigger '+file-templates/insert-license)

(setq evil-move-beyond-eol t)

(add-hook 'clojure-mode-hook 'lsp)
(add-hook 'clojurescript-mode-hook 'lsp)
(add-hook 'clojurec-mode-hook 'lsp)

(add-hook 'clojure-mode-hook #'evil-cleverparens-mode)
(add-hook 'clojurescript-mode-hook #'evil-cleverparens-mode)
(add-hook 'clojurec-mode-hook #'evil-cleverparens-mode)

(setq gc-cons-threshold (* 100 1024 1024)
      read-process-output-max (* 1024 1024)
      treemacs-space-between-root-nodes nil
      lsp-lens-enable t
      lsp-signature-auto-activate nil
                                        ; lsp-enable-indentation nil ; uncomment to use cider indentation instead of lsp
                                        ; lsp-enable-completion-at-point nil ; uncomment to use cider completion instead of lsp
      )

(after! smartparens
  (add-hook! (clojure-mode
              emacs-lisp-mode
              lisp-mode
              cider-repl-mode
              racket-mode
              racket-repl-mode) :append #'smartparens-strict-mode)
  (add-hook! smartparens-mode :append #'sp-use-paredit-bindings))

(setq cider-repl-pop-to-buffer-on-connect 'display-only)

(map! :map cider-repl-mode-map "RET" #'cider-repl-newline-and-indent)
(map! :map cider-repl-mode-map "C-RET" #'cider-repl-return)

(setq cider-repl-buffer-size-limit 1000000)
(setq cider-repl-result-prefix ";; => ")
(setq cider-repl-require-ns-on-set t)
(setq cider-auto-select-error-buffer nil)
(add-hook 'cider-repl-mode-hook '(lambda () (setq scroll-conservatively 101)))

(setq cider-print-options '(("length" 50000) ("right-margin" 70)))

(defun lein-lint()
  "Run lein lint-fix"
  (interactive)
  (shell-command "lein lint-fix"))

(set-file-template! "\\.nix$" :trigger "__" :mode 'nix-mode)

(set-file-template! "\\.py$" :trigger "__" :mode 'python-mode)

(defconst custom-leader "<s-tab>")

(map! :map general-override-mode-map
      :prefix custom-leader
      :desc ""                           ""  nil
      :desc "Zen mode"                   "z" #'writeroom-mode
      :desc "Doom reload"                "r" #'doom/reload
      :desc "Line numbers"               "l" #'doom/toggle-line-numbers
      :desc "Run lein lint-fix"          "L" #'lein-lint
      :desc "Indent style"               "I" #'doom/toggle-indent-style
      :desc "Word-wrap mode"             "w" #'+word-wrap-mode
      :desc "Format buffer"              "f" #'format-all-buffer
      :desc "Indent guides"              "i" #'highlight-indent-guides-mode
      :desc "Minimap mode"               "m" #'minimap-mode
      :desc "Spell checker"              "s" #'flyspell-mode
      :desc "Toggle Treemacs"            "p" #'treemacs
      :desc "evil-mc make all cursors"   "[" #'evil-mc-make-all-cursors
      :desc "evil-mc make next cursor"   "]" #'evil-mc-make-and-goto-next-match
      :desc "Switch to scratch buffer"   "X" #'doom/switch-to-scratch-buffer
      :desc "Open scratch buffer"        "x" #'doom/open-scratch-buffer)

(map! :map evil-window-map
      ;; Navigation
      "<left>"     #'evil-window-left
      "<down>"     #'evil-window-down
      "<up>"       #'evil-window-up
      "<right>"    #'evil-window-right
      "<end>"      #'end-of-line
      "<home>"     #'beginning-of-line
      ;; Swapping windows
      "C-<left>"       #'+evil/window-move-left
      "C-<down>"       #'+evil/window-move-down
      "C-<up>"         #'+evil/window-move-up
      "C-<right>"      #'+evil/window-move-right)

(map! :map evil-insert-state-map
      "<end>"  #'end-of-line
      "<home>" #'beginning-of-line)

(defun eval-and-replace ()
  "Replace the preceding sexp with its value."
  (interactive)
  (backward-kill-sexp)
  (condition-case nil
      (prin1 (eval (read (current-kill 0)))
             (current-buffer))
    (error (message "Invalid expression")
           (insert (current-kill 0)))))

(global-set-key (kbd "C-c e") 'eval-and-replace)

(setq auto-save-default t)

(defun doom-save () (let ((inhibit-message t)) #'doom-save-session))

(run-with-timer 30 30 #'doom-save)

;; LSP
(require 'lsp-mode)
(setq lsp-use-plists "true")

(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.devbox\\'"))

;;(lsp-register-custom-settings
;; '(("gopls.completeUnimported" t t)
;;   ("gopls.staticcheck" t t)))

(use-package! copilot
  :hook (prog-mode . copilot-mode)
  :bind (:map copilot-completion-map
              ("<tab>" . 'copilot-accept-completion)
              ("TAB" . 'copilot-accept-completion)
              ("C-TAB" . 'copilot-accept-completion-by-word)
              ("C-<tab>" . 'copilot-accept-completion-by-word))
  :config
  (setq copilot-indent-offset-warning-disable t)
  (add-to-list 'copilot-indentation-alist '(prog-mode . 2))
  (add-to-list 'copilot-indentation-alist '(org-mode . 2))
  (add-to-list 'copilot-indentation-alist '(text-mode . 2))
  (add-to-list 'copilot-indentation-alist '(closure-mode . 2))
  (add-to-list 'copilot-indentation-alist '(emacs-lisp-mode . 2))
  (add-to-list 'copilot-indentation-alist '(go-mode . 4)))

(after! (evil copilot)
  ;; Define the custom function that either accepts the completion or does the default behavior
  (defun my/copilot-tab-or-default ()
    (interactive)
    (if (and (bound-and-true-p copilot-mode)
             ;; Add any other conditions to check for active copilot suggestions if necessary
             )
        (copilot-accept-completion)
      (evil-insert 1))) ; Default action to insert a tab. Adjust as needed.

  ;; Bind the custom function to <tab> in Evil's insert state
  (evil-define-key 'insert 'global (kbd "<tab>") 'my/copilot-tab-or-default))

;; dockfmt is awful
(after! dockerfile-mode
  (setq-hook! 'dockerfile-mode-hook +format-with :none))

;; 1Password
(use-package! 1password
  :demand t
  :init
  (message "Enabling 1Password ...")
  :config
  (setq! 1password-op-executable (getenv "OP_BIN_PATH"))
  (1password-auth-source-enable))

;; LLM
(defvar openai-api-key nil "OpenAI API key")
(defvar openai-api-key-item-id "kbldmgnrk6fws4euhjj2ulmhxu" "OpenAI API key 1Password item id")

(defun get-openai-api-key()
  "Get the OpenAI API key"
  (or openai-api-key
      (setq openai-api-key (1password-get-field openai-api-key-item-id "api_key"))))

(use-package! llm
  :config
  (setq llm-warn-on-nonfree nil))

(use-package! magit-gptcommit
  :after magit llm
  :demand t
  :init
  (require 'llm-openai)
  :custom
  (magit-gptcommit-llm-provider (make-llm-openai :chat-model "gpt-4o-mini" :key (get-openai-api-key)))
  :config
  (magit-gptcommit-mode 1)
  (magit-gptcommit-status-buffer-setup)
  :bind (:map git-commit-mode-map
              ("C-c C-g" . magit-gptcommit-commit-accept)))

(use-package! ellama
  :after 1password llm
  :init
  (require 'llm-openai)
  (setopt ellama-provider (make-llm-openai :chat-model "gpt-4o" :key (get-openai-api-key)))
  (setopt ellama-naming-provider (make-llm-openai :chat-model "gpt-4o-mini" :key (get-openai-api-key)))
  :config
  (map! :leader
        (:prefix ("l" . "LLM")
         :desc "Chat" "c" #'ellama-chat
         :desc "Send" "s" #'ellama-complete
         :desc "Ask" "a" #'ellama-ask-about
         :desc "Translate" "t" #'ellama-translate
         :desc "Translate Buffer" "T" #'ellama-translate-buffer
         :desc "Summarize" "S" #'ellama-summarize
         :desc "Summarize Web Page" "W" #'ellama-summarize-webpage
         :desc "Change" "C" #'ellama-change
         :desc "Create List" "l" #'ellama-make-list
         :desc "Create Table" "L" #'ellama-make-table
         :desc "Add File" "f" #'ellama-context-add-file
         :desc "Add Buffer" "b" #'ellama-context-add-buffer
         :desc "Add Selection" "s" #'ellama-context-add-selection
         :desc "Solve Reasoning Problem" "p" #'ellama-solve-reasoning-problem
         :desc "Solve Domain Specific Problem" "P" #'ellama-solve-domain-specific-problem
         :desc "Code Review" "r" #'ellama-code-review)))

;; Code Review
(use-package! code-review
  :bind 
  (:map forge-topic-mode-map
              ("C-c r" . #'code-review-forge-pr-at-point))
  (:map code-review-mode-map
              ("C-c C-n" . #'code-review-comment-jump-next)
	      ("C-c C-p" . #'code-review-comment-jump-previous))
  :config
  (setq code-review-fill-column 80)
  (setq code-review-auth-login-marker 'forge)
  (add-hook 'code-review-mode-hook #'emojify-mode)
  (add-hook 'code-review-mode-hook
            (lambda ()
              ;; include *Code-Review* buffer into current workspace
              (persp-add-buffer (current-buffer)))))
