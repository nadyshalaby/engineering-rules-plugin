#!/bin/bash
# sample-repo.fixture.sh: a small "place an order" repository and a v2 trace over it, for the
# explore-feature script tests and the pipeline boot. `build_sample_repo <dir>` writes nine
# source files and commits them; `write_sample_trace <dir> <trace.json>` writes the trace with
# `root` pointing at that directory. Every line number in the trace is a claim about these
# files, which is exactly what verify-trace.sh exists to check.
fixture_here=${BASH_SOURCE[0]%/*}
[ "$fixture_here" = "${BASH_SOURCE[0]}" ] && fixture_here=.
SAMPLE_TRACE_TEMPLATE="$fixture_here/sample-trace.fixture.json"

sample_routes() {
  cat > "$1/src/orders/orders.routes.ts" <<'EOF'
import { Hono } from 'hono'
import { requireAuth } from '../platform/auth/require-auth.middleware'
import { createOrder } from './controllers/orders.controller'

export const ordersRoutes = new Hono()

ordersRoutes.post('/orders', requireAuth, createOrder)
EOF
}

sample_middleware() {
  cat > "$1/src/platform/auth/require-auth.middleware.ts" <<'EOF'
import type { Context, Next } from 'hono'
import { Unauthorized } from '../errors/unauthorized.error'

export async function requireAuth(c: Context, next: Next) {
  const session = c.get('session')
  if (!session) {
    throw new Unauthorized('no session on request')
  }
  c.set('user', session.user)
  await next()
}
EOF
}

sample_controller() {
  cat > "$1/src/orders/controllers/orders.controller.ts" <<'EOF'
import type { Context } from 'hono'
import { createOrderSchema } from '../schemas/orders.schema'
import { placeOrder } from '../services/orders.service'
import { ok } from '../../platform/http/envelope'

export async function createOrder(c: Context) {
  const input = createOrderSchema.parse(await c.req.json())
  const order = await placeOrder(c.get('user'), input)
  return c.json(ok(order), 201)
}
EOF
}

sample_schema() {
  cat > "$1/src/orders/schemas/orders.schema.ts" <<'EOF'
import { z } from 'zod'

export const createOrderSchema = z.object({
  sku: z.string().min(1),
  quantity: z.number().int().positive(),
})

export type CreateOrderInput = z.infer<typeof createOrderSchema>
EOF
}

sample_service() {
  cat > "$1/src/orders/services/orders.service.ts" <<'EOF'
import type { CreateOrderInput } from '../schemas/orders.schema'
import type { SessionUser } from '../../platform/auth/session.types'
import { insertOrder } from '../repositories/orders.repository'
import { sendReceipt } from '../../platform/email/email.service'
import { notify } from '../../platform/notify/notify'
import { OutOfStock } from '../errors/out-of-stock.error'

export async function placeOrder(user: SessionUser, input: CreateOrderInput) {
  const order = await insertOrder({ ...input, userId: user.id })
  if (order.backordered) {
    throw new OutOfStock(input.sku)
  }
  await sendReceipt(user.email, order)
  await notify('order.placed', order)
  return order
}
EOF
}

sample_repository() {
  cat > "$1/src/orders/repositories/orders.repository.ts" <<'EOF'
import { sql } from '../../platform/db/pool'
import type { NewOrder, Order } from '../types/orders.types'

export async function insertOrder(row: NewOrder): Promise<Order> {
  const [order] = await sql<Order[]>`
    insert into orders (sku, quantity, user_id)
    values (${row.sku}, ${row.quantity}, ${row.userId})
    returning *
  `
  return order
}
EOF
}

sample_email() {
  cat > "$1/src/platform/email/email.service.ts" <<'EOF'
import { resend } from './resend.client'
import type { Order } from '../../orders/types/orders.types'

export async function sendReceipt(to: string, order: Order) {
  await resend.emails.send({
    to,
    subject: `Order ${order.id}`,
    text: `Thanks for ordering ${order.quantity} x ${order.sku}`,
  })
}
EOF
}

sample_notify() {
  cat > "$1/src/platform/notify/notify.ts" <<'EOF'
import { handlers } from './handlers'

export async function notify(event: string, payload: unknown) {
  const matching = Object.entries(handlers).filter(([key]) => event.startsWith(key))
  for (const [, handler] of matching) await handler(payload)
}
EOF
  cat > "$1/src/platform/notify/handlers.ts" <<'EOF'
import { pushToSlack } from './slack.handler'
import { writeAudit } from './audit.handler'
export const handlers: Record<string, (payload: unknown) => Promise<void>> = {
  order: pushToSlack,
  'order.placed': writeAudit,
}
EOF
}

# build_sample_repo <dir>: the nine files, committed, so excerpts.json can name a commit.
build_sample_repo() {
  mkdir -p "$1/src/orders/controllers" "$1/src/orders/schemas" "$1/src/orders/services" \
    "$1/src/orders/repositories" "$1/src/platform/auth" "$1/src/platform/email" "$1/src/platform/notify"
  sample_routes "$1"; sample_middleware "$1"; sample_controller "$1"; sample_schema "$1"
  sample_service "$1"; sample_repository "$1"; sample_email "$1"; sample_notify "$1"
  git -C "$1" init -q
  git -C "$1" add src
  git -C "$1" -c user.name=fixture -c user.email=fixture@example.test commit -q -m 'sample repo'
}

# write_sample_trace <dir> <trace.json>: the template with root pointing at the sample repo.
write_sample_trace() {
  jq --arg root "$(cd "$1" && pwd -P)" '.root = $root' "$SAMPLE_TRACE_TEMPLATE" > "$2"
}
