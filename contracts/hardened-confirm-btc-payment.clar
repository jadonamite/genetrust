;; hardened-confirm-btc-payment
(define-public (confirm-btc-payment
    (escrow-id uint)
    (btc-txid (buff 32))
    (current-burn-height uint))

    (let ((escrow (unwrap! (map-get? btc-escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND)))
        (asserts! (is-eq (get status escrow) STATUS-AWAITING-BTC) ERR-INVALID-STATE)
        
        ;; 1. Verify Bitcoin tx spent to the correct platform address
        (let ((btc-tx (unwrap! (contract-call? .segwit-tx-parser get-verified-tx btc-txid) ERR-TX-NOT-VERIFIED)))
            
            ;; Check recipient (hardens against fraudulent tx submissions)
            (asserts! (is-eq (get recipient-witness-program btc-tx) (get recipient-witness-program escrow)) ERR-ADDRESS-MISMATCH)
            
            ;; Check amount
            (asserts! (>= (get amount-sats btc-tx) (get amount-sats escrow)) ERR-AMOUNT-INSUFFICIENT)

            ;; 2. Mark as spent to prevent replay attacks
            (try! (contract-call? .segwit-tx-parser mark-tx-spent btc-txid (unwrap-panic (to-consensus-buff? escrow-id))))

            ;; 3. Update state using merge
            (ok (map-set btc-escrows { escrow-id: escrow-id }
                (merge escrow {
                    btc-txid: (some btc-txid),
                    status: STATUS-BTC-CONFIRMED,
                    btc-confirmed-at: stacks-block-height,
                    challenge-deadline: (+ stacks-block-height CHALLENGE-PERIOD-BLOCKS)
                })
            ))
        )
    )
)
