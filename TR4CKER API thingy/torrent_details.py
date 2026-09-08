from dataclasses import dataclass
from datetime import datetime
from typing import Any, TypeVar, Callable, Type, cast
from datetime import datetime as dt


T = TypeVar("T")


def from_int(x: Any) -> int:
    assert isinstance(x, int) and not isinstance(x, bool)
    return x


def from_str(x: Any) -> str:
    assert isinstance(x, str)
    return x


def from_datetime(x: Any) -> datetime:
    return dt.strptime(x, "%Y-%m-%dT%H:%M:%S")


def from_list(f: Callable[[Any], T], x: Any) -> list[T]:
    assert isinstance(x, list)
    return [f(y) for y in x]


def from_bool(x: Any) -> bool:
    assert isinstance(x, bool)
    return x


def from_none(x: Any) -> Any:
    assert x is None
    return x


def to_class(c: Type[T], x: Any) -> dict:
    assert isinstance(x, c)
    return cast(Any, x).to_dict()


@dataclass
class Torrents:
    id: int
    slug: str
    info_hash: str
    name: str
    size_bytes: int
    file_count: int
    piece_length: int
    seeders: int
    leechers: int
    times_completed: int
    views: int
    created_at: datetime
    extra_info_format: str
    classic_description: str
    classic_description_format: str
    tags: list[Any]
    classic_cover_url: str
    is_freeleech: bool
    is_double_upload: bool
    is_anonymous: bool
    is_internal: bool
    is_exclusive: bool
    status: int
    source: str
    user_freeleech: bool
    freeleech_price: int
    is_favorited: bool
    cat_id: int
    cat_slug: str
    cat_name: str
    cat_icon: str
    sub_cat_id: int
    sub_cat_slug: str
    sub_cat_name: str
    uploader: str
    uploader_id: int
    files: list[Any]
    description: None = None
    extra_info: None = None
    tech_info_xml: None = None
    nfo: None = None
    poster_url: None = None
    year: None = None
    synopsis: None = None
    tmdb_id: None = None
    tmdb_type: None = None
    imdb_id: None = None
    tvdb_id: None = None
    rawg_id: None = None
    season: None = None
    episode: None = None
    episode_end: None = None
    release_type: None = None
    uploader_avatar: None = None
    uploader_banner: None = None
    uploader_signature: None = None

    @staticmethod
    def from_dict(obj: Any) -> 'Torrents':
        assert isinstance(obj, dict)
        id = from_int(obj.get("id"))
        slug = from_str(obj.get("slug"))
        info_hash = from_str(obj.get("info_hash"))
        name = from_str(obj.get("name"))
        size_bytes = from_int(obj.get("size_bytes"))
        file_count = from_int(obj.get("file_count"))
        piece_length = from_int(obj.get("piece_length"))
        seeders = from_int(obj.get("seeders"))
        leechers = from_int(obj.get("leechers"))
        times_completed = from_int(obj.get("times_completed"))
        views = from_int(obj.get("views"))
        created_at = from_datetime(obj.get("created_at"))
        extra_info_format = from_str(obj.get("extra_info_format"))
        classic_description = from_str(obj.get("classic_description"))
        classic_description_format = from_str(obj.get("classic_description_format"))
        tags = from_list(lambda x: x, obj.get("tags"))
        classic_cover_url = from_str(obj.get("classic_cover_url"))
        is_freeleech = from_bool(obj.get("is_freeleech"))
        is_double_upload = from_bool(obj.get("is_double_upload"))
        is_anonymous = from_bool(obj.get("is_anonymous"))
        is_internal = from_bool(obj.get("is_internal"))
        is_exclusive = from_bool(obj.get("is_exclusive"))
        status = from_int(obj.get("status"))
        source = from_str(obj.get("source"))
        user_freeleech = from_bool(obj.get("user_freeleech"))
        freeleech_price = from_int(obj.get("freeleech_price"))
        is_favorited = from_bool(obj.get("is_favorited"))
        cat_id = from_int(obj.get("cat_id"))
        cat_slug = from_str(obj.get("cat_slug"))
        cat_name = from_str(obj.get("cat_name"))
        cat_icon = from_str(obj.get("cat_icon"))
        sub_cat_id = from_int(obj.get("sub_cat_id"))
        sub_cat_slug = from_str(obj.get("sub_cat_slug"))
        sub_cat_name = from_str(obj.get("sub_cat_name"))
        uploader = from_str(obj.get("uploader"))
        uploader_id = from_int(obj.get("uploader_id"))
        files = from_list(lambda x: x, obj.get("files"))
        description = from_none(obj.get("description"))
        extra_info = from_none(obj.get("extra_info"))
        tech_info_xml = from_none(obj.get("tech_info_xml"))
        nfo = from_none(obj.get("nfo"))
        poster_url = from_none(obj.get("poster_url"))
        year = from_none(obj.get("year"))
        synopsis = from_none(obj.get("synopsis"))
        tmdb_id = from_none(obj.get("tmdb_id"))
        tmdb_type = from_none(obj.get("tmdb_type"))
        imdb_id = from_none(obj.get("imdb_id"))
        tvdb_id = from_none(obj.get("tvdb_id"))
        rawg_id = from_none(obj.get("rawg_id"))
        season = from_none(obj.get("season"))
        episode = from_none(obj.get("episode"))
        episode_end = from_none(obj.get("episode_end"))
        release_type = from_none(obj.get("release_type"))
        uploader_avatar = from_none(obj.get("uploader_avatar"))
        uploader_banner = from_none(obj.get("uploader_banner"))
        uploader_signature = from_none(obj.get("uploader_signature"))
        return Torrents(id, slug, info_hash, name, size_bytes, file_count, piece_length, seeders, leechers, times_completed, views, created_at, extra_info_format, classic_description, classic_description_format, tags, classic_cover_url, is_freeleech, is_double_upload, is_anonymous, is_internal, is_exclusive, status, source, user_freeleech, freeleech_price, is_favorited, cat_id, cat_slug, cat_name, cat_icon, sub_cat_id, sub_cat_slug, sub_cat_name, uploader, uploader_id, files, description, extra_info, tech_info_xml, nfo, poster_url, year, synopsis, tmdb_id, tmdb_type, imdb_id, tvdb_id, rawg_id, season, episode, episode_end, release_type, uploader_avatar, uploader_banner, uploader_signature)

    def to_dict(self) -> dict:
        result: dict = {}
        result["id"] = from_int(self.id)
        result["slug"] = from_str(self.slug)
        result["info_hash"] = from_str(self.info_hash)
        result["name"] = from_str(self.name)
        result["size_bytes"] = from_int(self.size_bytes)
        result["file_count"] = from_int(self.file_count)
        result["piece_length"] = from_int(self.piece_length)
        result["seeders"] = from_int(self.seeders)
        result["leechers"] = from_int(self.leechers)
        result["times_completed"] = from_int(self.times_completed)
        result["views"] = from_int(self.views)
        result["created_at"] = self.created_at.isoformat()
        result["extra_info_format"] = from_str(self.extra_info_format)
        result["classic_description"] = from_str(self.classic_description)
        result["classic_description_format"] = from_str(self.classic_description_format)
        result["tags"] = from_list(lambda x: x, self.tags)
        result["classic_cover_url"] = from_str(self.classic_cover_url)
        result["is_freeleech"] = from_bool(self.is_freeleech)
        result["is_double_upload"] = from_bool(self.is_double_upload)
        result["is_anonymous"] = from_bool(self.is_anonymous)
        result["is_internal"] = from_bool(self.is_internal)
        result["is_exclusive"] = from_bool(self.is_exclusive)
        result["status"] = from_int(self.status)
        result["source"] = from_str(self.source)
        result["user_freeleech"] = from_bool(self.user_freeleech)
        result["freeleech_price"] = from_int(self.freeleech_price)
        result["is_favorited"] = from_bool(self.is_favorited)
        result["cat_id"] = from_int(self.cat_id)
        result["cat_slug"] = from_str(self.cat_slug)
        result["cat_name"] = from_str(self.cat_name)
        result["cat_icon"] = from_str(self.cat_icon)
        result["sub_cat_id"] = from_int(self.sub_cat_id)
        result["sub_cat_slug"] = from_str(self.sub_cat_slug)
        result["sub_cat_name"] = from_str(self.sub_cat_name)
        result["uploader"] = from_str(self.uploader)
        result["uploader_id"] = from_int(self.uploader_id)
        result["files"] = from_list(lambda x: x, self.files)
        result["description"] = from_none(self.description)
        result["extra_info"] = from_none(self.extra_info)
        result["tech_info_xml"] = from_none(self.tech_info_xml)
        result["nfo"] = from_none(self.nfo)
        result["poster_url"] = from_none(self.poster_url)
        result["year"] = from_none(self.year)
        result["synopsis"] = from_none(self.synopsis)
        result["tmdb_id"] = from_none(self.tmdb_id)
        result["tmdb_type"] = from_none(self.tmdb_type)
        result["imdb_id"] = from_none(self.imdb_id)
        result["tvdb_id"] = from_none(self.tvdb_id)
        result["rawg_id"] = from_none(self.rawg_id)
        result["season"] = from_none(self.season)
        result["episode"] = from_none(self.episode)
        result["episode_end"] = from_none(self.episode_end)
        result["release_type"] = from_none(self.release_type)
        result["uploader_avatar"] = from_none(self.uploader_avatar)
        result["uploader_banner"] = from_none(self.uploader_banner)
        result["uploader_signature"] = from_none(self.uploader_signature)
        return result


def torrents_from_dict(s: Any) -> Torrents:
    return Torrents.from_dict(s)


def torrents_to_dict(x: Torrents) -> Any:
    return to_class(Torrents, x)
