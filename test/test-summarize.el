;;; test-summarize.el --- Tests for transcript summarization -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for the ACP session handling in `agent-recall-summarize'.
;; Run with:
;;   emacs --batch -l agent-recall.el -l test/test-summarize.el -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'agent-recall)

(ert-deftest agent-recall-summarize-stderr-notice-does-not-tear-down ()
  "Agent stderr output is a notice, not a fatal error.

acp.el turns every non-empty stderr line into an error handler call
\(for example the acp-multiplex startup banner).  The summarizer must
log it and keep the session alive; only request failures tear down."
  (let ((work-buffer (generate-new-buffer " *test-summarize-work*"))
        (progress-buffer (generate-new-buffer " *test-summarize-progress*"))
        (shutdown-calls 0))
    (unwind-protect
        (cl-letf (((symbol-function 'acp-shutdown)
                   (lambda (&rest _) (cl-incf shutdown-calls))))
          (with-current-buffer work-buffer
            (setq agent-recall--summarize-client '((:process . nil))))
          (agent-recall--summarize-handle-agent-error
           work-buffer progress-buffer
           '((code . -32603)
             (message . "acp-multiplex: socket /tmp/x.sock, log /tmp/x.log")))
          (should (buffer-live-p work-buffer))
          (should (= shutdown-calls 0))
          (should (with-current-buffer work-buffer
                    agent-recall--summarize-client))
          (should (string-match-p "acp-multiplex: socket"
                                  (with-current-buffer progress-buffer
                                    (buffer-string)))))
      (ignore-errors (kill-buffer work-buffer))
      (ignore-errors (kill-buffer progress-buffer)))))

(ert-deftest agent-recall-summary-parent-file-maps-summary-to-transcript ()
  "A TIMESTAMP.summary.md hit resolves to its TIMESTAMP.md transcript."
  (should (equal (agent-recall--summary-parent-file
                  "/p/.agent-shell/transcripts/2026-07-09-16-24-09.summary.md")
                 "/p/.agent-shell/transcripts/2026-07-09-16-24-09.md"))
  (should (equal (agent-recall--summary-parent-file
                  "/p/.agent-shell/transcripts/2026-07-09-16-24-09.summary.org")
                 "/p/.agent-shell/transcripts/2026-07-09-16-24-09.org"))
  (should (equal (agent-recall--summary-parent-file
                  "/p/.agent-shell/transcripts/2026-07-09-16-24-09.md")
                 "/p/.agent-shell/transcripts/2026-07-09-16-24-09.md"))
  (should-not (agent-recall--summary-parent-file nil)))

(ert-deftest agent-recall-summary-parent-file-preserves-match-data ()
  "Callers read match data after mapping the file; it must survive."
  (should (string-match "\\(b\\)" "abc"))
  (agent-recall--summary-parent-file "/p/x.summary.md")
  (should (equal (match-string 1 "abc") "b"))
  (should (= (match-end 0) 2)))

(provide 'test-summarize)
;;; test-summarize.el ends here
