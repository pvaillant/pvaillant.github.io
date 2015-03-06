---
layout : layout
title : Lync SDK posts
---

<h2>Posts tagged with Lync SDK</h2>
<ul class="tagged-posts">
{% for post in site.posts %}{% for t in post.tags %}{% if t == "Lync-SDK" %}
	<li><p><a href="{{ post.url }}">{{ post.title }}</a> &mdash; {{ post.date | date: "%B %d" }} &mdash; <a href="{{ post.url }}#disqus_thread">Comments</a></p></li>
{% endif %}{% endfor %}{% endfor %}
</ul>
