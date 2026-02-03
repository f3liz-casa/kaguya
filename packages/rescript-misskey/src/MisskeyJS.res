// Main module for rescript-misskey
// Re-exports all public APIs with a clean interface

// ============================================================
// Common types
// ============================================================

module Common = MisskeyJS_Common
include Common

// ============================================================
// Entity types
// ============================================================

module User = MisskeyJS_User
module Note = MisskeyJS_Note
module Notification = MisskeyJS_Notification
module DriveTypes = MisskeyJS_Drive

// ============================================================
// Unified Client (main entry point)
// ============================================================

module Client = MisskeyJS_Client

// ============================================================
// Major APIs (top-level, easy access - 80% of use cases)
// ============================================================

// Timeline - fetch and subscribe to timelines
module Timeline = MisskeyJS_Timeline

// Custom Timelines - fetch available antennas, lists, channels
module CustomTimelines = MisskeyJS_CustomTimelines

// Notifications - fetch and subscribe to notifications
module Notifications = MisskeyJS_Notifications

// Notes - create, show, delete, react
module Notes = MisskeyJS_Notes

// Me - current user operations
module Me = MisskeyJS_Me

// MiAuth - OAuth-like authentication flow
module MiAuth = MisskeyJS_MiAuth

// Emojis - custom emoji operations
module Emojis = MisskeyJS_Emojis

// ============================================================
// Less-common APIs (via submodules - 20% of use cases)
// ============================================================

// API - Users, Following, Drive, Meta
module API = MisskeyJS_API

// Stream - Drive channel, ServerStats channel
module Stream = MisskeyJS_Stream

// ============================================================
// Utilities
// ============================================================

module Acct = MisskeyJS_Acct
module Constants = MisskeyJS_Constants

// ============================================================
// Convenience type re-exports
// ============================================================

type client = Client.t
type timelineType = Timeline.timelineType
type timelineSubscription = Timeline.subscription
type notificationsSubscription = Notifications.subscription
