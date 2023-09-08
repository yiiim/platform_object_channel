# url_launcher_platform_interface

A common platform interface for the [`platform_object_channel`][1] plugin.

This interface allows platform-specific implementations of the `platform_object_channel`
plugin, as well as the plugin itself, to ensure they are supporting the
same interface.

# Usage

To implement a new platform-specific implementation of `platform_object_channel`, extend
[`PlatformObjectChannelInterface`][2] with an implementation that performs the
platform-specific behavior, and when you register your plugin, set the default
`PlatformObjectChannelInterface` by calling
`PlatformObjectChannelInterface.instance = MyPlatformObjectChannel()`.

[1]: ../platform_object_channel
[2]: lib/platform_object_channel_interface.dart