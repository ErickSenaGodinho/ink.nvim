-- lua/ink/collections/init.lua
-- Public interface for collections module

local M = {}

-- Import submodules
local data = require("ink.collections.data")
local management = require("ink.collections.management")
local associations = require("ink.collections.associations")
local queries = require("ink.collections.queries")
local maintenance = require("ink.collections.maintenance")

-- === COLLECTION MANAGEMENT ===

-- Create new collection
M.create = management.create

-- Rename collection
M.rename = management.rename

-- Update collection metadata
M.update = management.update

-- Delete collection
M.delete = management.delete

-- Get collection by ID
M.get = management.get

-- Get all collections
M.get_all = management.get_all

-- === BOOK-COLLECTION ASSOCIATION ===

-- Add book to collection
M.add_book = associations.add_book

-- Remove book from collection
M.remove_book = associations.remove_book

-- Check if book is in collection
M.has_book = associations.has_book

-- Get collections containing a book
M.get_book_collections = associations.get_book_collections

-- Move book between collections
M.move_book = associations.move_book

-- Remove book from all collections
M.remove_book_from_all = associations.remove_book_from_all

-- === QUERIES ===

-- Get books in collection with full library data
M.get_collection_books = queries.get_collection_books

-- Count books in collection
M.count_books = queries.count_books

-- Get average reading progress for collection
M.get_collection_progress = queries.get_collection_progress

-- Filter books by multiple collections
M.filter_books = queries.filter_books

-- Get empty collections
M.get_empty_collections = queries.get_empty_collections

-- Search collections
M.search = queries.search

-- Invalidate stats cache
M.invalidate_stats = queries.invalidate_stats

-- === MAINTENANCE ===

-- Remove orphaned books
M.cleanup_orphaned_books = maintenance.cleanup_orphaned_books

-- Recalculate statistics
M.recalculate_stats = maintenance.recalculate_stats

-- Export collections
M.export = maintenance.export

-- Import collections
M.import = maintenance.import

-- Get statistics
M.get_statistics = maintenance.get_statistics

-- === INTERNAL/ADVANCED ===

-- Direct access to data layer (for advanced use)
M.data = data

return M
