// Drive file entity types

@@warning("-30") // Duplicate field names in recursive types are intentional
open MisskeyJS_Common

// File properties
type driveFileProperties = {
  width: option<int>,
  height: option<int>,
  orientation: option<int>,
  avgColor: option<string>,
}

type rec driveFile = {
  id: id,
  createdAt: dateString,
  name: string,
  @as("type") type_: string,
  md5: string,
  size: int,
  isSensitive: bool,
  blurhash: option<string>,
  properties: driveFileProperties,
  url: string,
  thumbnailUrl: option<string>,
  comment: option<string>,
  folderId: option<id>,
  folder: option<driveFolder>,
  userId: option<id>,
  user: option<JSON.t>, // Forward reference to User
}
and driveFolder = {
  id: id,
  createdAt: dateString,
  name: string,
  foldersCount: option<int>,
  filesCount: option<int>,
  parentId: option<id>,
  parent: option<driveFolder>,
}

type t = driveFile
type folder = driveFolder
