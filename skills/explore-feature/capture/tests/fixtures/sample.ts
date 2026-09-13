"use strict";
import { EventEmitter } from "node:events";

export async function sendEstimate(orderId: string, { mode, email }: { mode: string; email: string }): Promise<string> {
  if (mode === "email") {
    return `sent ${orderId} to ${email}`;
  }
  const kind = mode === "print" ? "printed" : "skipped";
  return `${kind} ${orderId}`;
}

export function classify(n: number): string {
  switch (n > 0 ? "pos" : "other") {
    case "pos": return "positive";
    default: return n === 0 ? "zero" : "negative";
  }
}

export function boom(reason: string): never {
  throw new RangeError(reason);
}

export function later(v: number): Promise<number> {
  return new Promise((resolve) => setTimeout(() => resolve(v * 2), 1));
}

export class Orders {
  private items: string[] = [];
  get count(): number { return this.items.length; }
  add(id: string, [first, ...rest]: string[] = []): number {
    this.items.push(id, first ?? "", ...rest);
    return this.items.length;
  }
}

export const twice = (x: number) => x * 2;

export const emitter = new EventEmitter();
emitter.on("ping", (payload: { password: string; user: string }) => { return payload.user; });

export function log(msg: string): void {
  if (!msg) return;
  emitter.emit("log", msg);
}

export function outside(a: number): number {
  if (a > 1) return a;
  return -a;
}
