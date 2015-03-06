---
layout : layout
title : Philips Hue posts
---

<h2>Posts tagged with Philips Hue</h2>
<ul class="tagged-posts">
{% for post in site.posts %}{% for t in post.tags %}{% if t == "Philips-Hue" %}
	<li><p><a href="{{ post.url }}">{{ post.title }}</a> &mdash; {{ post.date | date: "%B %d" }} &mdash; <a href="{{ post.url }}#disqus_thread">Comments</a></p></li>
{% endif %}{% endfor %}{% endfor %}
</ul>
