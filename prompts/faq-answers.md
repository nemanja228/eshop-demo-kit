# FAQ — canonical answers (operator only)

Answer ONLY if a run asks. Verbatim, nothing more. Log every question asked (cell, rep,
question, answer given) in runs/runs.md. If a run asks something not covered here, answer:
"Your call — make a reasonable decision and record it." and log the question for the
post-run review.

**Q: What should happen if an archived item is already in a customer's basket?**
A: The item stays visible in the basket, but checkout is blocked with a message naming the
archived item; the customer must remove it to complete the order.

**Q: Should admins see archived items in the admin list?**
A: Yes. Admins see all items, with archived ones clearly marked, so they can unarchive
them.

**Q: Should the API still return archived items (list / get by id)?**
A: The customer-facing view must not show archived items. The admin flow must still be
able to list and fetch them. How you achieve that at the API level is your design
decision.

**Q: How quickly must archiving take effect on the storefront?**
A: Promptly. A short propagation delay (up to about a minute) is acceptable only if it is
deliberate and documented.

**Q: What about existing orders / order history?**
A: Past orders must remain exactly as they were, including item names and images.

**Q: Should archiving delete anything?**
A: No. Archiving is reversible; no data is deleted.

**Q: Default state for new and for existing items?**
A: Not archived.

**Q: Should the storefront brand/type filters or counts include archived items?**
A: Customer-facing filtering applies to non-archived items only.

**Q: UI expectations for the admin?**
A: Minimal and consistent with the existing admin UI. No new design work.
