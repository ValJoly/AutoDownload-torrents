from enum import Enum
from dataclasses import dataclass
from typing import Any, TypeVar, Callable, Type, cast
from datetime import datetime
from datetime import datetime as dt


T = TypeVar("T")
EnumT = TypeVar("EnumT", bound=Enum)


def from_str(x: Any) -> str:
    assert isinstance(x, str)
    return x


def from_int(x: Any) -> int:
    assert isinstance(x, int) and not isinstance(x, bool)
    return x


def from_bool(x: Any) -> bool:
    assert isinstance(x, bool)
    return x


def from_list(f: Callable[[Any], T], x: Any) -> list[T]:
    assert isinstance(x, list)
    return [f(y) for y in x]


def from_datetime(x: Any) -> datetime:
    return dt.strptime(x, "%Y-%m-%dT%H:%M:%S")


def from_none(x: Any) -> Any:
    assert x is None
    return x


def from_union(fs, x):
    for f in fs:
        try:
            return f(x)
        except:
            pass
    assert False


def to_enum(c: Type[EnumT], x: Any) -> EnumT:
    assert isinstance(x, c)
    return x.value


def to_class(c: Type[T], x: Any) -> dict:
    assert isinstance(x, c)
    return cast(Any, x).to_dict()


class ParentCatIcon(Enum):
    MENU_BOOK = "menu_book"


class ParentCatName(Enum):
    LIVRES = "Livres"


class ParentCatSlug(Enum):
    LIVRES = "livres"


@dataclass
class UploaderBadge:
    name: str
    img: str

    @staticmethod
    def from_dict(obj: Any) -> 'UploaderBadge':
        assert isinstance(obj, dict)
        name = from_str(obj.get("name"))
        img = from_str(obj.get("img"))
        return UploaderBadge(name, img)

    def to_dict(self) -> dict:
        result: dict = {}
        result["name"] = from_str(self.name)
        result["img"] = from_str(self.img)
        return result


@dataclass
class Torrent:
    id: int
    slug: str
    name: str
    size_bytes: int
    file_count: int
    seeders: int
    leechers: int
    times_completed: int
    is_freeleech: bool
    is_anonymous: bool
    tags: list[str]
    created_at: datetime
    parent_cat_id: int
    parent_cat_slug: ParentCatSlug
    parent_cat_name: ParentCatName
    parent_cat_icon: ParentCatIcon
    uploader: str
    uploader_badges: list[UploaderBadge]
    poster_url: None = None
    year: None = None
    synopsis: None = None
    tmdb_id: None = None
    imdb_id: None = None
    tvdb_id: None = None
    rawg_id: None = None
    season: None = None
    episode: None = None
    episode_end: None = None
    release_type: None = None
    sub_cat_id: int | None = None
    sub_cat_slug: str | None = None
    sub_cat_name: str | None = None
    sub_cat_icon: str | None = None
    description_snippet: None = None
    classic_cover_url: str | None = None
    source: str | None = None

    @staticmethod
    def from_dict(obj: Any) -> 'Torrent':
        assert isinstance(obj, dict)
        id = from_int(obj.get("id"))
        slug = from_str(obj.get("slug"))
        name = from_str(obj.get("name"))
        size_bytes = from_int(obj.get("size_bytes"))
        file_count = from_int(obj.get("file_count"))
        seeders = from_int(obj.get("seeders"))
        leechers = from_int(obj.get("leechers"))
        times_completed = from_int(obj.get("times_completed"))
        is_freeleech = from_bool(obj.get("is_freeleech"))
        is_anonymous = from_bool(obj.get("is_anonymous"))
        tags = from_list(from_str, obj.get("tags"))
        created_at = from_datetime(obj.get("created_at"))
        parent_cat_id = from_int(obj.get("parent_cat_id"))
        parent_cat_slug = ParentCatSlug(obj.get("parent_cat_slug"))
        parent_cat_name = ParentCatName(obj.get("parent_cat_name"))
        parent_cat_icon = ParentCatIcon(obj.get("parent_cat_icon"))
        uploader = from_str(obj.get("uploader"))
        uploader_badges = from_list(UploaderBadge.from_dict, obj.get("uploader_badges"))
        poster_url = from_none(obj.get("poster_url"))
        year = from_none(obj.get("year"))
        synopsis = from_none(obj.get("synopsis"))
        tmdb_id = from_none(obj.get("tmdb_id"))
        imdb_id = from_none(obj.get("imdb_id"))
        tvdb_id = from_none(obj.get("tvdb_id"))
        rawg_id = from_none(obj.get("rawg_id"))
        season = from_none(obj.get("season"))
        episode = from_none(obj.get("episode"))
        episode_end = from_none(obj.get("episode_end"))
        release_type = from_none(obj.get("release_type"))
        sub_cat_id = from_union([from_int, from_none], obj.get("sub_cat_id"))
        sub_cat_slug = from_union([from_none, from_str], obj.get("sub_cat_slug"))
        sub_cat_name = from_union([from_none, from_str], obj.get("sub_cat_name"))
        sub_cat_icon = from_union([from_none, from_str], obj.get("sub_cat_icon"))
        description_snippet = from_none(obj.get("description_snippet"))
        classic_cover_url = from_union([from_none, from_str], obj.get("classic_cover_url"))
        source = from_union([from_none, from_str], obj.get("source"))
        return Torrent(id, slug, name, size_bytes, file_count, seeders, leechers, times_completed, is_freeleech, is_anonymous, tags, created_at, parent_cat_id, parent_cat_slug, parent_cat_name, parent_cat_icon, uploader, uploader_badges, poster_url, year, synopsis, tmdb_id, imdb_id, tvdb_id, rawg_id, season, episode, episode_end, release_type, sub_cat_id, sub_cat_slug, sub_cat_name, sub_cat_icon, description_snippet, classic_cover_url, source)

    def to_dict(self) -> dict:
        result: dict = {}
        result["id"] = from_int(self.id)
        result["slug"] = from_str(self.slug)
        result["name"] = from_str(self.name)
        result["size_bytes"] = from_int(self.size_bytes)
        result["file_count"] = from_int(self.file_count)
        result["seeders"] = from_int(self.seeders)
        result["leechers"] = from_int(self.leechers)
        result["times_completed"] = from_int(self.times_completed)
        result["is_freeleech"] = from_bool(self.is_freeleech)
        result["is_anonymous"] = from_bool(self.is_anonymous)
        result["tags"] = from_list(from_str, self.tags)
        result["created_at"] = self.created_at.isoformat()
        result["parent_cat_id"] = from_int(self.parent_cat_id)
        result["parent_cat_slug"] = to_enum(ParentCatSlug, self.parent_cat_slug)
        result["parent_cat_name"] = to_enum(ParentCatName, self.parent_cat_name)
        result["parent_cat_icon"] = to_enum(ParentCatIcon, self.parent_cat_icon)
        result["uploader"] = from_str(self.uploader)
        result["uploader_badges"] = from_list(lambda x: to_class(UploaderBadge, x), self.uploader_badges)
        result["poster_url"] = from_none(self.poster_url)
        result["year"] = from_none(self.year)
        result["synopsis"] = from_none(self.synopsis)
        result["tmdb_id"] = from_none(self.tmdb_id)
        result["imdb_id"] = from_none(self.imdb_id)
        result["tvdb_id"] = from_none(self.tvdb_id)
        result["rawg_id"] = from_none(self.rawg_id)
        result["season"] = from_none(self.season)
        result["episode"] = from_none(self.episode)
        result["episode_end"] = from_none(self.episode_end)
        result["release_type"] = from_none(self.release_type)
        result["sub_cat_id"] = from_union([from_int, from_none], self.sub_cat_id)
        result["sub_cat_slug"] = from_union([from_none, from_str], self.sub_cat_slug)
        result["sub_cat_name"] = from_union([from_none, from_str], self.sub_cat_name)
        result["sub_cat_icon"] = from_union([from_none, from_str], self.sub_cat_icon)
        result["description_snippet"] = from_none(self.description_snippet)
        result["classic_cover_url"] = from_union([from_none, from_str], self.classic_cover_url)
        result["source"] = from_union([from_none, from_str], self.source)
        return result


@dataclass
class Torrents:
    limit: int
    page: int
    torrents: list[Torrent]
    total: int
    total_capped: bool

    @staticmethod
    def from_dict(obj: Any) -> 'Torrents':
        assert isinstance(obj, dict)
        limit = from_int(obj.get("limit"))
        page = from_int(obj.get("page"))
        torrents = from_list(Torrent.from_dict, obj.get("torrents"))
        total = from_int(obj.get("total"))
        total_capped = from_bool(obj.get("total_capped"))
        return Torrents(limit, page, torrents, total, total_capped)

    def to_dict(self) -> dict:
        result: dict = {}
        result["limit"] = from_int(self.limit)
        result["page"] = from_int(self.page)
        result["torrents"] = from_list(lambda x: to_class(Torrent, x), self.torrents)
        result["total"] = from_int(self.total)
        result["total_capped"] = from_bool(self.total_capped)
        return result


def torrents_from_dict(s: Any) -> Torrents:
    return Torrents.from_dict(s)


def torrents_to_dict(x: Torrents) -> Any:
    return to_class(Torrents, x)
