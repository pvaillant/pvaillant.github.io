---
layout : layout
title : ThinkTel posts - Paul's UC and Dev/Ops Blog
---

<h2>Posts tagged with ThinkTel</h2>
<ul class="tagged-posts">
{% for post in site.posts %}{% for t in post.tags %}{% if t == "ThinkTel" %}
	<li><p><a href="{{ post.url }}">{{ post.title }}</a> &mdash; {{ post.date | date: "%B %d" }} &mdash; <a href="{{ post.url }}#disqus_thread">Comments</a></p></li>
{% endif %}{% endfor %}{% endfor %}
</ul>